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
| `release-type` | | | リリースタイプ (例: `node`, `python` 等)。config-file/manifest-fileを使用しない場合に指定 |
| `target-branch` | | | release-pleaseの対象ブランチ |

## 出力

### 単一パッケージ

| 名前 | 説明 |
|------|------|
| `release_created` | リリースが作成されたかどうか |
| `tag_name` | 作成されたリリースのタグ名 |
| `upload_url` | 作成されたリリースのアップロードURL |
| `major` | 作成されたリリースのメジャーバージョン |
| `minor` | 作成されたリリースのマイナーバージョン |
| `patch` | 作成されたリリースのパッチバージョン |

### モノレポ・共通

| 名前 | 説明 |
|------|------|
| `releases_created` | いずれかのリリースが作成されたかどうか |
| `prs_created` | リリースPRが作成・更新されたかどうか |
| `pr` | リリースPRの番号 |
| `paths_released` | リリースされたパスの一覧 (JSON文字列) |
| `all` | release-pleaseの全出力 (JSON文字列)。モノレポでパッケージ別の出力を取得する際に使用 |

## 使用例

### 基本的な使用方法

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

### release-typeを直接指定

config-file/manifest-fileを使わず、release-typeを直接指定する場合:

```yaml
- uses: buffett-code-dev/github-actions/github/release-please@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    release-type: node
    target-branch: main
```

### GitHub App Tokenを使用

botアカウントではリリースPRのCIが起動しない場合に、GitHub App TokenやPATを使用:

```yaml
- name: Generate GitHub App Token
  id: generate_token
  uses: actions/create-github-app-token@v3
  with:
    app-id: ${{ secrets.GH_APP_ID }}
    private-key: ${{ secrets.GH_APP_PRIVATE_KEY }}
    owner: ${{ github.repository_owner }}

- uses: buffett-code-dev/github-actions/github/release-please@main
  with:
    github-token: ${{ steps.generate_token.outputs.token }}
```

### モノレポでパッケージ別の出力を使用

`all` 出力からパッケージ別の値を取得する場合:

```yaml
jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      releases-created: ${{ steps.release.outputs.releases_created }}
      all: ${{ steps.release.outputs.all }}
    steps:
      - uses: buffett-code-dev/github-actions/github/release-please@main
        id: release
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}

  deploy:
    needs: [release-please]
    if: ${{ fromJSON(needs.release-please.outputs.all)['packages/my-pkg--release_created'] == 'true' }}
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying ${{ fromJSON(needs.release-please.outputs.all)['packages/my-pkg--tag_name'] }}"
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

- リポジトリのルートに `release-please-config.json` と `.release-please-manifest.json` が存在すること（`release-type` 直接指定の場合は不要）
- ワークフローが `contents: write` と `pull-requests: write` 権限を持っていること
- コミットメッセージが [Conventional Commits](https://www.conventionalcommits.org/) に準拠していること
