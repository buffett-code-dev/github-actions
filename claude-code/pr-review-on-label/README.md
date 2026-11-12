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
      actions: read # ci_workflow を指定する場合に必要
      checks: read # self_merge_policy_path を指定する場合に必要
      contents: read
      pull-requests: write
      statuses: read # self_merge_policy_path を指定する場合に必要

    steps:
      - uses: buffett-code-dev/github-actions/claude-code/pr-review-on-label@main
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ github.token }}
          ci_workflow: ci.yml
```

`claude-review` ラベルは呼び出し元のリポジトリに作成してください。Draft PR も対象です。

## 入力

| 入力 | 必須 | 説明 |
| --- | --- | --- |
| `anthropic_api_key` | はい | Claude Code Action が使用する Anthropic API キー |
| `github_token` | はい | PR の読み取りとレビューコメントの投稿に使うジョブの GitHub トークン |
| `ci_workflow` | いいえ | 成功を確認する `pull_request` ワークフローのファイル名（例: `ci.yml`）または ID。既定値は空文字列（確認なし） |
| `self_merge_policy_path` | いいえ | ベースコミットにあるセルフマージガイドラインのリポジトリ相対パス。既定値は空文字列 |

Action はベースコミットをチェックアウトし、GitHub CLI で対象 PR の概要と差分を取得します。レビュー結果は `pass`、`changes_requested`、`needs_human` のいずれかを先頭に付けて、PR に投稿します。

## セルフマージの事前判定

呼び出し元の `with` に `self_merge_policy_path: docs/development/self-merge-guidelines.md` のように、リポジトリで管理するガイドラインのパスを指定できます。Claude はベースコミットのガイドラインを読み、対象コミット SHA とセルフマージの事前判定をコードレビューと同じコメントに記載します。

判定は変更内容がセルフマージの対象に該当するかを示す「可能」「不可能」の二択で、マージ実行の許可ではありません。ガイドラインにレベル別の条件がある場合は各レベルについて判定し、著者のレベルは推測しません。レベル別の条件がない場合は PR 全体について判定します。

- **可能**: 今回のコードレビューが `pass` で、以下の「不可能」の条件に該当せず、ガイドラインの変更内容に関する条件（レベル別の場合はそのレベルの条件）をすべて満たすと確認できた場合。
- **不可能**: レビューが `pass` 以外、ガイドライン・差分・最新 SHA を確認できない、判定対象の SHA と最新 SHA が異なる、PR がガイドラインや判定基準として参照する文書を変更している（追加・削除・改名を含む）、またはガイドラインの禁止条件に該当する・変更内容に関する条件を満たさない場合。情報不足や人の判断が必要で変更内容に関する条件を満たすと確認できない場合も含みます。

各判定には根拠となる条項と変更ファイルを添えます。「不可能」の場合は、満たしていない条件、未確認の項目、人に確認すべき点も具体的に示します。パスを省略した場合は通常のコードレビューを行います。

CI 成功・レビュー完了・結果の記録などの手続き条件は、事前判定とは別の「マージ前に確認する項目」欄に記載します。今回のレビュー結果を使い、過去のレビューや投稿前のコメント URL が存在しないことを理由に「不可能」とはしません。コメントには該当条項・根拠・検証結果・対象 SHA を記録します。

`gh pr view --json headRefOid,statusCheckRollup` で対象 SHA の CI 状況を取得するため、呼び出し元のジョブに `checks: read` と `statuses: read` を付けてください。取得失敗・未実行・未完了・失敗は成功と扱わず、実行中の今回のレビュージョブも完了済みとは扱いません。**事前判定が「可能」でも、著者は最新 CI の成功、今回のレビューの完了と `pass`、投稿後の結果 URL の記録を含むガイドラインの必須事項をすべて確認してからマージしてください。**

## レビュー前の CI 確認

`ci_workflow` を指定すると、チェックアウトや Claude の起動前に、ラベル付与時の PR 番号・head SHA・ベースブランチに一致する最新のワークフロー実行が成功していることを確認します。CI を複数回実行した場合は最新の実行を優先し、再実行中もレビューを開始しません。確認対象は `pull_request` イベントの実行です。

未実行・未完了・失敗、API の取得失敗、または確認後の PR の head SHA・ベースブランチがラベル付与時と異なる場合は、Action を失敗させて Claude の起動を止めます。最新コミットの CI 成功後に `claude-review` ラベルを外して付け直してください。CI の完了待ちや、自動でのレビュー再開は行いません。

呼び出し元のジョブに `actions: read` 権限を付けてください。Composite Action から呼び出し元の権限を追加することはできません。ランナーには Ruby と GitHub CLI が必要です（上記の `ubuntu-latest` にはインストール済みです）。`ci_workflow` を省略した場合は CI 確認をスキップし、従来どおりレビューします。

## テスト

```sh
ruby claude-code/pr-review-on-label/ci_gate_test.rb
```

GitHub CLI をスタブし、Action 内の CI 確認スクリプトを実行します。API への接続や Claude の起動は行いません。
