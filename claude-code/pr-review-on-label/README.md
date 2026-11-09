# Claude PR Review on Label

ラベル付与をきっかけに、Claude が PR の差分をレビューし、結果を PR コメントに投稿する Composite Action です。

## 使用方法

呼び出し元のワークフローでラベルを指定し、同じリポジトリ内の PR に対象を絞ります。

```yaml
name: Claude Review on Label

on:
  pull_request:
    types: [labeled]

jobs:
  review:
    if: >-
      github.event.label.name == 'claude-review' &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    timeout-minutes: 15
    concurrency:
      group: claude-review-${{ github.event.pull_request.number }}
      cancel-in-progress: true
    permissions:
      contents: read
      pull-requests: write

    steps:
      - uses: buffett-code-dev/github-actions/claude-code/pr-review-on-label@main
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ github.token }}
```

`claude-review` ラベルは呼び出し元のリポジトリに作成してください。Draft PR も対象です。

## 入力

| 入力 | 必須 | 説明 |
| --- | --- | --- |
| `anthropic_api_key` | はい | Claude Code Action が使用する Anthropic API キー |
| `github_token` | はい | PR の読み取りとレビューコメントの投稿に使うジョブの GitHub トークン |
| `self_merge_policy_path` | いいえ | ベースコミットにあるセルフマージガイドラインのリポジトリ相対パス。既定値は空文字列 |

Action はベースコミットをチェックアウトし、GitHub CLI で対象 PR の概要と差分を取得します。レビュー結果は `pass`、`changes_requested`、`needs_human` のいずれかを先頭に付けて、PR に投稿します。

## セルフマージの事前判定

呼び出し元の `with` に `self_merge_policy_path: docs/development/self-merge-guidelines.md` のように、リポジトリで管理するガイドラインのパスを指定できます。Claude はベースコミットのガイドラインを読み、対象コミット SHA とセルフマージの事前判定をコードレビューと同じコメントに記載します。

パスを省略した場合は通常のコードレビューを行います。ガイドラインを取得できない場合、判定対象のコミットが更新された場合、または PR がガイドラインや判定基準として参照する文書を変更する場合は、事前判定を要人間確認として報告します。
