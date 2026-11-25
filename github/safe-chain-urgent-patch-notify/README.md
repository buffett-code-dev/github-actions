# Safe-chain Urgent Patch Notify

Dependabot の PR で更新される npm パッケージのうち、[safe-chain](https://github.com/AikidoSec/safe-chain) の最小公開期間で CI のインストールが止まり、かつ緊急性の高い脆弱性を修正するものを検知して Slack に通知する composite action です。

safe-chain は、公開から一定時間（デフォルト48時間）が経過していないバージョンのインストールを拒否します。Dependabot の cooldown はセキュリティアップデートには適用されないため、脆弱性を修正する PR がこの期間に止まることがあります。このアクションは、その中から待たずに対応を検討すべきものを通知します。除外設定の追加とマージは人が判断します。

## 判定条件

次の条件をすべて満たす更新を通知します。

1. 更新後のバージョンの公開からの経過時間が `minimum-age-hours` 未満である（npm registry の公開日時で判定）
2. 更新前のバージョンに影響し、更新後のバージョンには影響しない GHSA（GitHub Security Advisory）がある
3. その GHSA の深刻度が `severities` に含まれる、または CVE が [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) に掲載されている

GHSA は GitHub Advisory Database の公開 API で取得します。Dependabot アラートの API は使わないため、追加の権限は不要です。

## 使用方法

```yaml
name: safe-chain urgent patch notify

on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read

jobs:
  notify:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - uses: buffett-code-dev/github-actions/github/safe-chain-urgent-patch-notify@main
        with:
          slack-webhook-url: ${{ secrets.SLACK_WEBHOOK_URL_DEV_SECURITY }}
```

Dependabot が起動したワークフローでは、通常の Actions secrets を参照できません。Webhook の URL は **Dependabot secrets** に登録してください。

## パラメータ

| パラメータ | 説明 | 必須 | デフォルト |
|-----------|------|------|-----------|
| `slack-webhook-url` | 通知先の Slack Incoming Webhook URL | Yes | - |
| `lockfile` | npm の lockfile のパス | No | `package-lock.json` |
| `minimum-age-hours` | safe-chain の最小公開期間（時間） | No | `48` |
| `severities` | 通知対象とする GHSA の深刻度（カンマ区切り）。CISA KEV 掲載の脆弱性は深刻度に関係なく通知する | No | `critical` |
| `github-token` | GitHub API の呼び出しに使うトークン | No | `${{ github.token }}` |

## 出力

| 出力 | 説明 |
|------|------|
| `urgent` | 緊急性の高い更新があれば `true` |

## 制限事項

- 対象は npm（`package-lock.json` v2 以降）のみです。
- PR が更新されるたびに判定するため、同じ PR について通知が重複することがあります。
