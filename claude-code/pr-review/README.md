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

## 関連リンク

- [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
