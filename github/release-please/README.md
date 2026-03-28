# github/release-please

[release-please](https://github.com/googleapis/release-please) を使用してリリースPRとGitHubリリースを自動作成するComposite Actionです。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/github/release-please@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `github-token` | Yes | | GitHubトークン (contents write, pull-requests write権限が必要) |
| `config-file` | | `release-please-config.json` | release-please設定ファイルのパス |
| `manifest-file` | | `.release-please-manifest.json` | release-pleaseマニフェストファイルのパス |

## 出力

| 名前 | 説明 |
|------|------|
| `release_created` | リリースが作成されたかどうか |
| `tag_name` | 作成されたリリースのタグ名 |
| `upload_url` | 作成されたリリースのアップロードURL |

## 使用例

### 基本的な使用方法 (手動実行)

```yaml
name: Release Please

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: buffett-code-dev/github-actions/github/release-please@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### リリース後に追加処理を実行

```yaml
name: Release Please

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: buffett-code-dev/github-actions/github/release-please@main
        id: release
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Post-release action
        if: ${{ steps.release.outputs.release_created }}
        run: echo "Released ${{ steps.release.outputs.tag_name }}"
```

### 設定ファイルのパスを指定

```yaml
- uses: buffett-code-dev/github-actions/github/release-please@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    config-file: custom-release-please-config.json
    manifest-file: custom-manifest.json
```

## 動作

1. `release-please-config.json` と `.release-please-manifest.json` を元にリリース対象を判定します
2. Conventional Commits に基づいてバージョンを自動決定します
3. リリースPRを作成または更新します
4. リリースPRがマージされると、GitHubリリースとタグを自動作成します

## 前提条件

- リポジトリのルートに `release-please-config.json` と `.release-please-manifest.json` が存在すること
- ワークフローが `contents: write` と `pull-requests: write` 権限を持っていること
- コミットメッセージが [Conventional Commits](https://www.conventionalcommits.org/) に準拠していること
