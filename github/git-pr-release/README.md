# github/git-pr-release

staging ブランチから production ブランチへのリリースPRを自動作成するComposite Actionです。
[git-pr-release](https://github.com/x-motemen/git-pr-release) を使用して、リリースに含まれるPR一覧をチェックリスト形式で本文に含んだPRを作成します。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/github/git-pr-release@main
  with:
    branch-production: main
    branch-staging: develop
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `github-token` | | `${{ github.token }}` | GitHubトークン (pull request write権限が必要) |
| `branch-production` | Yes | | 本番ブランチ名 |
| `branch-staging` | Yes | | ステージングブランチ名 |
| `squashed` | | `true` | squash mergeされたPRも含める |
| `labels` | | `release` | リリースPRに付与するラベル (カンマ区切り) |
| `template` | | | リリースPR本文のERBテンプレートファイルパス |
| `ruby-version` | | `3.4` | 使用するRubyバージョン |
| `timezone` | | `Asia/Tokyo` | リリースPRのタイムスタンプに使用するタイムゾーン |

## 使用例

### 基本的な使用方法 (定期実行)

```yaml
name: Create release PR

on:
  schedule:
    - cron: '0 0 * * 1'  # 毎週月曜0時に実行
  workflow_dispatch:

jobs:
  release-pr:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: buffett-code-dev/github-actions/github/git-pr-release@main
        with:
          branch-production: main
          branch-staging: develop
```

### ブランチ名をカスタマイズ

```yaml
- uses: buffett-code-dev/github-actions/github/git-pr-release@main
  with:
    branch-production: master
    branch-staging: development
```

### ラベル付きリリースPR

```yaml
- uses: buffett-code-dev/github-actions/github/git-pr-release@main
  with:
    labels: release
```

### developへのpush時にも実行

```yaml
name: Create release PR

on:
  push:
    branches:
      - develop
  schedule:
    - cron: '0 0 * * 1'
  workflow_dispatch:

jobs:
  release-pr:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: buffett-code-dev/github-actions/github/git-pr-release@main
        with:
          branch-production: main
          branch-staging: develop
```

## 動作

1. production ブランチと staging ブランチの差分を確認します
2. 差分がない場合はスキップします
3. 差分がある場合、staging → production のリリースPRを作成 (既存のリリースPRがあれば更新) します
4. リリースPRの本文には、含まれるPRの一覧がチェックリスト形式で記載されます

## 前提条件

- `actions/checkout` で `fetch-depth: 0` を指定して全履歴を取得すること
- ワークフローが `pull-requests: write` 権限を持っていること
