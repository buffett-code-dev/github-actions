# github/create-release-reminder-issue

GitHub Flow リポジトリで、最後のリリース以降に未リリースのコミットがある場合にリマインド用の Issue を作成する Composite Action です。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/github/create-release-reminder-issue@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    base-branch: main
    assignees: "user1,user2"
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `github-token` | Yes | | GitHubトークン (issues write権限が必要) |
| `base-branch` | Yes | | 未リリースコミットを確認するブランチ |
| `assignees` | Yes | | Issue にアサインする GitHub ユーザー名 (カンマ区切り) |

## 使用例

### 基本的な使用方法 (週次実行)

```yaml
name: Release reminder

on:
  schedule:
    - cron: '0 0 * * 1'  # 毎週月曜0時に実行
  workflow_dispatch:

jobs:
  reminder:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: buffett-code-dev/github-actions/github/create-release-reminder-issue@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          base-branch: main
          assignees: "user1,user2"
```

## 動作

1. `gh release view` で最新のリリースを取得します
2. リリースが存在しない場合はスキップします
3. 最後のリリースと base-branch に差分がない場合はスキップします
4. 上記条件を満たす場合、リマインド Issue を作成します

### Issue の内容

- `/releases/new` へのリンク

## 前提条件

- `actions/checkout` で `fetch-depth: 0` を指定して全履歴とタグを取得すること
- ワークフローが `issues: write` 権限を持っていること
- リポジトリに `release-required` ラベルを事前に作成しておくこと
