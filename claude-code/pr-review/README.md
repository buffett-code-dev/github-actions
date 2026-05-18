# Claude PR Review

Claude Code Actionを使用したPRレビューとIssue対応を行うComposite Actionです。

## 概要

PRやIssueで `@claude` をメンションすると、Claude AIがコードレビューや質問への回答を行います。

## 使用方法

各リポジトリの `.github/workflows/claude.yml` に以下のように設定します：

```yaml
name: Claude PR Assistant

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]

jobs:
  claude-code-action:
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude')) ||
      (github.event_name == 'issues' && contains(github.event.issue.body, '@claude'))
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
      issues: read
      id-token: write
    steps:
      - name: Run Claude PR Review
        uses: buffett-code-dev/github-actions/claude-code/pr-review@main
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
```

## 入力パラメータ

| パラメータ | 必須 | デフォルト値 | 説明 |
|-----------|------|-------------|------|
| `anthropic_api_key` | Yes | - | Anthropic API Key |
| `timeout_minutes` | No | `60` | タイムアウト時間（分） |
| `allowed_bots` | No | (未設定) | 許可するボットのリスト（カンマ区切り） |
| `checkout_fetch_depth` | No | `1` | チェックアウト時のfetch-depth |

## カスタマイズ例

### タイムアウト時間を変更

```yaml
- name: Run Claude PR Review
  uses: buffett-code-dev/github-actions/claude/pr-review@main
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    timeout_minutes: '30'
```

### 複数のボットを許可

```yaml
- name: Run Claude PR Review
  uses: buffett-code-dev/github-actions/claude/pr-review@main
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    allowed_bots: 'buffett-code-bot,dependabot[bot]'
```

## 必要なシークレット

- `ANTHROPIC_API_KEY`: Anthropic APIキー（Organization secretsで設定推奨）

## CLAUDE.md / AGENTS.md の取り扱い

チェックアウト後、リポジトリルートに対して以下のチェックを行います:

1. `CLAUDE.md` が `AGENTS.md` へのシンボリックリンクの場合: シンボリックリンクを削除して `AGENTS.md` の実体をコピーします
2. `CLAUDE.md` が存在する場合: そのまま使用します
3. `CLAUDE.md` が無く `AGENTS.md` が存在する場合: `AGENTS.md` を `CLAUDE.md` としてコピーします
4. どちらも存在しない場合: エラーメッセージを出力してActionを失敗させます

`AGENTS.md` を使っているリポジトリでも、ファイルを重複管理せずに Claude PR Review を利用できるようにするための挙動です。

なお、シンボリックリンクを実体コピーに置き換えているのは、`claude-code-action` v1.0.89 以降で `SENSITIVE_PATHS` にsymlinkが含まれると `cpSync` が `ENOENT` でクラッシュするバグがあるためです（[anthropics/claude-code-action#1187](https://github.com/anthropics/claude-code-action/issues/1187)）。

## セキュリティに関する注意事項

このActionでは、`anthropics/claude-code-action` のバージョンを `v1` のようなメジャーバージョン指定ではなく、`v1.0.29` のようにパッチバージョンまで明記しています。これは、よりセキュアに運用するための措置です。

## 関連リンク

- [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
