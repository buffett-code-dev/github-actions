// Dependabot の PR で更新される npm パッケージのうち、
// safe-chain の最小公開期間に引っかかり、かつ緊急性の高い脆弱性を修正するものを検知して Slack に通知する。
//
// 判定条件（すべて満たすもの）:
// - 更新後のバージョンの公開からの経過時間が minimum-age-hours 未満
// - 更新前のバージョンに影響し、更新後のバージョンには影響しない GHSA がある
// - その GHSA の深刻度が severities に含まれる、または CVE が CISA KEV に掲載されている

const KEV_URL = 'https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json';

module.exports = async ({ github, context, core }) => {
  const lockfile = process.env.INPUT_LOCKFILE;
  const minimumAgeHours = Number(process.env.INPUT_MINIMUM_AGE_HOURS);
  const severities = process.env.INPUT_SEVERITIES.split(',').map((s) => s.trim().toLowerCase());
  const webhookUrl = process.env.INPUT_SLACK_WEBHOOK_URL;

  const pr = context.payload.pull_request;
  if (!pr) {
    core.setFailed('pull_request イベントで実行してください');
    return;
  }

  const [basePackages, headPackages] = await Promise.all([
    readLockfilePackages(github, context.repo, lockfile, pr.base.sha),
    readLockfilePackages(github, context.repo, lockfile, pr.head.sha),
  ]);

  const updates = collectUpdates(basePackages, headPackages);
  core.info(`更新されたパッケージ: ${updates.length} 件`);

  const youngUpdates = [];
  for (const update of updates) {
    const publishedAt = await fetchPublishedAt(update.name, update.to);
    if (!publishedAt) continue;
    const ageHours = (Date.now() - publishedAt.getTime()) / 36e5;
    if (ageHours < minimumAgeHours) {
      youngUpdates.push({ ...update, publishedAt, ageHours });
    }
  }
  core.info(`公開から ${minimumAgeHours} 時間未満の更新: ${youngUpdates.length} 件`);
  if (youngUpdates.length === 0) {
    core.setOutput('urgent', 'false');
    return;
  }

  const kevCves = await fetchKevCves(core);

  const urgentUpdates = [];
  for (const update of youngUpdates) {
    const fixed = await fetchFixedAdvisories(github, update);
    const urgent = fixed.filter(
      (a) => severities.includes(a.severity) || (a.cve_id && kevCves.has(a.cve_id)),
    );
    if (urgent.length > 0) {
      urgentUpdates.push({ ...update, advisories: urgent.map((a) => ({ ...a, kev: kevCves.has(a.cve_id) })) });
    }
  }
  core.info(`緊急性の高い更新: ${urgentUpdates.length} 件`);
  core.setOutput('urgent', String(urgentUpdates.length > 0));
  if (urgentUpdates.length === 0) return;

  const text = buildMessage({ context, pr, urgentUpdates, minimumAgeHours });
  core.summary.addRaw(text).write();
  if (!webhookUrl) {
    core.warning('slack-webhook-url が空のため、Slack への通知を省略しました');
    core.info(text);
    return;
  }
  const res = await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  });
  if (!res.ok) {
    core.setFailed(`Slack への通知に失敗しました: ${res.status}`);
  }
};

async function readLockfilePackages(github, repo, path, ref) {
  try {
    const res = await github.rest.repos.getContent({ ...repo, path, ref, mediaType: { format: 'raw' } });
    return JSON.parse(res.data).packages ?? {};
  } catch (e) {
    if (e.status === 404) return {};
    throw e;
  }
}

// lockfile の packages を「パッケージ名 → バージョンの集合」に変換し、
// head にだけあるバージョンを更新後、同名パッケージの base のバージョンを更新前とみなす
function collectUpdates(basePackages, headPackages) {
  const toVersionMap = (packages) => {
    const map = new Map();
    for (const [key, value] of Object.entries(packages)) {
      if (!key.includes('node_modules/') || !value.version || value.link) continue;
      const name = key.slice(key.lastIndexOf('node_modules/') + 'node_modules/'.length);
      if (!map.has(name)) map.set(name, new Set());
      map.get(name).add(value.version);
    }
    return map;
  };
  const base = toVersionMap(basePackages);
  const head = toVersionMap(headPackages);

  const updates = [];
  for (const [name, versions] of head) {
    const baseVersions = base.get(name);
    if (!baseVersions) continue;
    for (const to of versions) {
      if (baseVersions.has(to)) continue;
      for (const from of baseVersions) {
        if (!versions.has(from)) updates.push({ name, from, to });
      }
    }
  }
  return updates;
}

async function fetchPublishedAt(name, version) {
  const res = await fetch(`https://registry.npmjs.org/${name.replace('/', '%2f')}`);
  if (!res.ok) return null;
  const time = (await res.json()).time?.[version];
  return time ? new Date(time) : null;
}

async function fetchKevCves(core) {
  try {
    const res = await fetch(KEV_URL);
    if (!res.ok) throw new Error(`status ${res.status}`);
    return new Set((await res.json()).vulnerabilities.map((v) => v.cveID));
  } catch (e) {
    core.warning(`CISA KEV の取得に失敗したため、深刻度だけで判定します: ${e.message}`);
    return new Set();
  }
}

// 更新前のバージョンに影響し、更新後のバージョンには影響しない advisory を返す
async function fetchFixedAdvisories(github, { name, from, to }) {
  const list = async (version) =>
    (await github.request('GET /advisories', { ecosystem: 'npm', affects: `${name}@${version}`, per_page: 100 })).data;
  const [before, after] = await Promise.all([list(from), list(to)]);
  const remaining = new Set(after.map((a) => a.ghsa_id));
  return before.filter((a) => !remaining.has(a.ghsa_id));
}

function buildMessage({ context, pr, urgentUpdates, minimumAgeHours }) {
  const lines = [
    `:rotating_light: safe-chain の最小公開期間（${minimumAgeHours} 時間）で止まる、緊急性の高い脆弱性修正があります`,
    `<${pr.html_url}|${context.repo.owner}/${context.repo.repo}#${pr.number} ${pr.title}>`,
  ];
  for (const u of urgentUpdates) {
    const unblockAt = new Date(u.publishedAt.getTime() + minimumAgeHours * 36e5);
    lines.push('', `*${u.name}* ${u.from} → ${u.to}（safe-chain の制限解除: ${formatJst(unblockAt)}）`);
    for (const a of u.advisories) {
      const epss = a.epss?.percentage != null ? `、EPSS ${(a.epss.percentage * 100).toFixed(2)}%` : '';
      const kev = a.kev ? '、*KEV 掲載*' : '';
      lines.push(`• <${a.html_url}|${a.ghsa_id}>${a.cve_id ? ` (${a.cve_id})` : ''} 深刻度 ${a.severity}${kev}${epss}: ${a.summary}`);
    }
  }
  lines.push(
    '',
    '到達可能性を確認し、待てない場合は `.aikido` に次の設定を追加して PR にコミットしてください（マージ後に削除）。',
    '```',
    'safe-chain:',
    '  npm:',
    '    minimumPackageAgeExclusions:',
    ...[...new Set(urgentUpdates.map((u) => u.name))].map((n) => `      - "${n}"`),
    '```',
  );
  return lines.join('\n');
}

function formatJst(date) {
  return date.toLocaleString('ja-JP', { timeZone: 'Asia/Tokyo', dateStyle: 'short', timeStyle: 'short' });
}
