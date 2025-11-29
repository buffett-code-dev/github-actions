# github/dependabot-auto-merge

Dependabotが作成したPRを条件に応じて自動マージするComposite Actionです。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/github/dependabot-auto-merge@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `github-token` | | `${{ github.token }}` | PR書き込み権限を持つGitHubトークン |
| `pr-url` | | `${{ github.event.pull_request.html_url }}` | マージ対象のPR URL |
| `update-type` | | `version-update:semver-patch` | 自動マージする更新タイプ |

## 更新タイプ

`update-type`で指定できる値:

- `version-update:semver-patch` - パッチバージョン更新のみ (1.0.0 → 1.0.1)
- `version-update:semver-minor` - マイナーバージョン更新まで (1.0.0 → 1.1.0)
- `version-update:semver-major` - メジャーバージョン更新まで (1.0.0 → 2.0.0)

## 使用例

### 基本的な使用方法 (パッチのみ自動マージ)

```yaml
name: Dependabot auto-merge

on: pull_request

permissions:
  pull-requests: write
  contents: write

jobs:
  dependabot:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - uses: buffett-code-dev/github-actions/github/dependabot-auto-merge@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### マイナーバージョン更新も自動マージ

```yaml
- uses: buffett-code-dev/github-actions/github/dependabot-auto-merge@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    update-type: version-update:semver-minor
```

### すべての更新を自動マージ

```yaml
- uses: buffett-code-dev/github-actions/github/dependabot-auto-merge@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    update-type: version-update:semver-major
```

### 承認後に自動マージ (より安全)

```yaml
name: Dependabot auto-merge

on:
  pull_request_review:
    types: [submitted]

permissions:
  pull-requests: write
  contents: write

jobs:
  dependabot:
    runs-on: ubuntu-latest
    if: |
      github.actor == 'dependabot[bot]' &&
      github.event.review.state == 'approved'
    steps:
      - uses: buffett-code-dev/github-actions/github/dependabot-auto-merge@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### CI成功後に自動マージ

```yaml
name: Dependabot auto-merge

on:
  pull_request:
  workflow_run:
    workflows: ["CI"]
    types: [completed]

permissions:
  pull-requests: write
  contents: write

jobs:
  dependabot:
    runs-on: ubuntu-latest
    if: |
      github.actor == 'dependabot[bot]' &&
      github.event.workflow_run.conclusion == 'success'
    steps:
      - uses: buffett-code-dev/github-actions/github/dependabot-auto-merge@main
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## 動作

1. Dependabotのメタデータを取得
2. 更新タイプが指定した条件に一致するかチェック
3. 条件に一致する場合、PRに対して自動マージを有効化
4. ブランチ保護ルールの条件が満たされたら自動的にマージされる

## 注意事項

- **デフォルトではパッチバージョン更新のみが対象です**
- 自動マージが有効になっても、ブランチ保護ルール (CI成功、承認など) の条件を満たす必要があります
- `if: github.actor == 'dependabot[bot]'` の条件を必ず付けることを推奨します

## 前提条件

- Dependabotが有効化されていること
- ワークフローに`pull-requests: write`と`contents: write`権限が付与されていること
- (オプション) ブランチ保護ルールでCI成功や承認が必須の場合、それらの条件が設定されていること
