# github/label-stale-items

一定期間更新がないissue/PRに自動的にラベルを付与するComposite Actionです。

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
| `stale-issue-label` | | `stale` | issueに付与するラベル名 |
| `days-before-pr-stale` | | `14` | PRをstaleとマークするまでの日数 (`-1`で無効) |
| `days-before-pr-close` | | `21` | stale後にPRをcloseするまでの日数 (`-1`でcloseしない) |
| `stale-pr-label` | | `stale` | PRに付与するラベル名 |

## 使用例

### 基本的な使用方法 (定期実行)

```yaml
name: Label stale items

on:
  schedule:
    - cron: '0 0 * * *'  # 毎日0時に実行

jobs:
  stale:
    runs-on: ubuntu-latest
    permissions:
      issues: write
      pull-requests: write
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

### PRをstale対象から外す

```yaml
- uses: buffett-code-dev/github-actions/github/label-stale-items@main
  with:
    days-before-pr-stale: -1  # PRは対象外
```

### 手動実行も可能にする

```yaml
name: Label stale items

on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:  # 手動実行を許可

jobs:
  stale:
    runs-on: ubuntu-latest
    permissions:
      issues: write
      pull-requests: write
    steps:
      - uses: buffett-code-dev/github-actions/github/label-stale-items@main
        with:
          days-before-issue-stale: 60
```

## 動作

- 指定した日数以上更新がないissue/PRに対して、ラベルを付与します
- staleとマークされた後、さらに指定日数が経過するとcloseされます (設定されている場合)
- staleメッセージは日本語で投稿されます:
  - Issue: 「このissueは{日数}日以上放置されています。」
  - PR: 「このPRは{日数}日以上放置されています。」

## 注意事項

- **デフォルトではissueの自動closeは無効です** (`days-before-issue-close: -1`)
- **デフォルトではPRはstale後21日でcloseされます** (`days-before-pr-close: 21`)
- staleラベルが付いたissue/PRに新しいコメントやアクティビティがあると、ラベルは自動的に削除されます

## 前提条件

- リポジトリに指定したラベル (`stale`など) が存在すること (存在しない場合は自動作成されます)
- ワークフローが以下の権限を持っていること:
  - `issues: write` (issueにラベル付与・close するため)
  - `pull-requests: write` (PRにラベル付与・close するため、PR対象時)
