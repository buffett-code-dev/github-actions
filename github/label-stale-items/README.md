# github/label-stale-items

一定期間更新がないissueに自動的にラベルを付与するComposite Actionです。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/github/label-stale-items@main
  with:
    repo-token: ${{ secrets.GITHUB_TOKEN }}
    days-before-issue-stale: 60
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `repo-token` | | `${{ github.token }}` | GitHubトークン |
| `days-before-issue-stale` | | `60` | issueをstaleとマークするまでの日数 |
| `days-before-issue-close` | | `-1` | stale後にissueをcloseするまでの日数 (`-1`でcloseしない) |
| `stale-issue-label` | | `stale` | 付与するラベル名 |
| `days-before-pr-stale` | | `-1` | PRをstaleとマークするまでの日数 (`-1`で無効) |
| `days-before-pr-close` | | `-1` | stale後にPRをcloseするまでの日数 (`-1`でcloseしない) |

## 使用例

### 基本的な使用方法 (定期実行)

```yaml
name: Label stale issues

on:
  schedule:
    - cron: '0 0 * * *'  # 毎日0時に実行

jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: buffett-code-dev/github-actions/github/label-stale-items@main
```

### カスタム設定

```yaml
- uses: buffett-code-dev/github-actions/github/label-stale-items@main
  with:
    days-before-issue-stale: 90  # 90日間更新なしでstale
    stale-issue-label: '古いissue'  # カスタムラベル
```

### Stale後に自動クローズ

```yaml
- uses: buffett-code-dev/github-actions/github/label-stale-items@main
  with:
    days-before-issue-stale: 60
    days-before-issue-close: 7  # stale後7日でclose
```

### PRにも適用

```yaml
- uses: buffett-code-dev/github-actions/github/label-stale-items@main
  with:
    days-before-issue-stale: 60
    days-before-pr-stale: 30  # PRは30日でstale
    days-before-pr-close: 14  # stale後14日でclose
```

### 手動実行も可能にする

```yaml
name: Label stale issues

on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:  # 手動実行を許可

jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: buffett-code-dev/github-actions/github/label-stale-items@main
        with:
          days-before-issue-stale: 60
```

## 動作

- 指定した日数以上更新がないissue/PRに対して、ラベルを付与します
- staleとマークされた後、さらに指定日数が経過するとcloseされます (設定されている場合)
- staleメッセージは日本語で投稿されます:
  - Issue: 「このissueは{日数}日以上経過しています。」
  - PR: 「このPRは{日数}日以上経過しています。」

## 注意事項

- **デフォルトではPRへの適用は無効です** (`days-before-pr-stale: -1`)
- **デフォルトでは自動closeは無効です** (`days-before-issue-close: -1`)
- staleラベルが付いたissue/PRに新しいコメントやアクティビティがあると、ラベルは自動的に削除されます

## 前提条件

- リポジトリに指定したラベル (`stale`など) が存在すること (存在しない場合は自動作成されます)
- ワークフローが`issues: write`権限を持っていること (通常は自動的に付与されます)
