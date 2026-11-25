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
    # CI 待機10分と、レビュー・終了通知の時間を確保する
    timeout-minutes: 30
    concurrency:
      group: claude-review-${{ github.event.pull_request.number }}
      cancel-in-progress: true
    permissions:
      actions: read # ci_workflow を指定する場合に必要
      contents: read
      pull-requests: write

    steps:
      - uses: buffett-code-dev/github-actions/claude-code/pr-review-on-label@main
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ github.token }}
          ci_workflow: ci.yml
          ci_wait_timeout_seconds: '600'
          ci_start_timeout_seconds: '300'
          ci_poll_interval_seconds: '30'
          ci_base_branches: development,master
```

`claude-review` ラベルは呼び出し元のリポジトリに作成してください。Draft PR も対象です。

ラベルを付与できるのは人間のユーザーと Devin（`devin-ai-integration`）です。その他の bot が付与した場合、Claude Code Action が実行を拒否します。

## 入力

| 入力 | 必須 | 説明 |
| --- | --- | --- |
| `anthropic_api_key` | はい | Claude Code Action が使用する Anthropic API キー |
| `github_token` | はい | PR の読み取りとレビューコメントの投稿に使うジョブの GitHub トークン |
| `ci_workflow` | いいえ | 成功を確認する `pull_request` ワークフローのファイル名（例: `ci.yml`）または ID。既定値は空文字列（確認なし） |
| `ci_wait_timeout_seconds` | いいえ | CI 完了の最大待機秒数。正の整数、既定値 `600`（10分） |
| `ci_start_timeout_seconds` | いいえ | 対象 CI が未作成の場合の開始猶予秒数。正の整数、既定値 `300`（5分） |
| `ci_poll_interval_seconds` | いいえ | CI の確認間隔秒数。正の整数、既定値 `30` |
| `ci_base_branches` | いいえ | CI の対象ベースブランチのカンマ区切り一覧。既定値は空文字列（制限なし） |
| `self_merge_policy_path` | いいえ | ベースコミットにあるセルフマージガイドラインのリポジトリ相対パス。既定値は空文字列 |

Action はベースコミットをチェックアウトし、GitHub CLI で対象 PR の概要と差分を取得します。レビュー結果は `pass`、`changes_requested`、`needs_human` のいずれかを先頭に付けて、PR に投稿します。

## セルフマージの事前判定

呼び出し元の `with` に `self_merge_policy_path: docs/development/self-merge-guidelines.md` のように、リポジトリで管理するガイドラインのパスを指定できます。Claude はベースコミットのガイドラインを読み、対象コミット SHA とセルフマージの事前判定をコードレビューと同じコメントに記載します。

判定は「可能」「不可能」の二択です。ガイドラインにレベル別の条件がある場合は各レベルについて判定し、著者のレベルは推測しません。レベル別の条件がない場合は PR 全体について判定します。

- **可能**: コードレビューが `pass` で、以下の「不可能」の条件に該当せず、ガイドラインの条件（レベル別の場合はそのレベルの条件）をすべて満たすと確認できた場合。
- **不可能**: レビューが `pass` 以外、ガイドライン・差分・最新 SHA を確認できない、判定対象の SHA と最新 SHA が異なる、PR がガイドラインや判定基準として参照する文書を変更している（追加・削除・改名を含む）、またはガイドラインの禁止条件に該当する・必要な条件を満たさない場合。情報不足や人の判断が必要で条件を満たすと確認できない場合も含みます。

各判定には根拠となる条項と変更ファイルを添えます。「不可能」の場合は、満たしていない条件、未確認の項目、人に確認すべき点も具体的に示します。パスを省略した場合は通常のコードレビューを行います。

## レビュー前の CI 確認

`ci_workflow` を指定すると、チェックアウトや Claude の起動前に、ラベル付与時の PR 番号・head SHA・ベースブランチに一致する最新のワークフロー実行が成功していることを確認します。CI を複数回実行した場合は最新の実行を優先し、再実行中もレビューを開始しません。確認対象は `pull_request` イベントの実行です。

CI が未完了なら、既定で30秒間隔・最大10分待ち、成功した時点で自動でレビューを開始します。CI が未作成の場合は、開始直後の遅延を考慮して最大5分待ちます。`ci_base_branches` の対象外は待機せず、理由を PR に通知して失敗として終了します。CI を再実行した場合も、最新の実行が完了するまで待ちます。

ラベル付与時に状態コメントを作成し、同じコメントを「CI 開始待ち」「CI 完了待ち」「レビュー中」「レビュー処理完了」または具体的なエラーに更新します。コメントには対象 SHA と Actions のリンク、対象 CI が見つかればそのリンクも記載します。レビュー結果は Claude が別のコメントに投稿します。状態コメントは依頼ごとに1件とし、以前の実行の終了通知が新しい依頼の状態を上書きしないようにします。

CI 失敗・キャンセル・タイムアウト・開始猶予超過・API エラーでは理由を通知し、Action を失敗させます。待機中とレビュー開始前に PR の状態を取得し、head SHA・ベースブランチの変更、PR のクローズ、依頼ラベルの取り外しがあれば終了します。Claude にも差分取得前と投稿直前の対象 SHA・ベースブランチの確認を指示し、レビュー処理の終了後にも再確認します。追加 push 後やエラーの解消後はラベルを外して付け直してください。手元で CI 成功を待つ必要はありません。

ジョブ全体の `timeout-minutes` は CI 待機上限にレビューと終了通知の余裕を加えて指定してください（上の例は30分）。待機の期限はスクリプト内で管理するため、期限超過時も状態通知を行います。ジョブの強制終了や runner の停止、GitHub API の障害時には通知できない場合があります。キャンセル通知は可能な範囲で行います。

待機中も runner を使用し、Actions の実行時間を消費します。上記の例の30分はジョブ全体の上限です。`ci_wait_timeout_seconds` は利用リポジトリの CI 所要時間と待機コストに応じて調整してください。

ポーリング1回につき PR の状態と CI 実行一覧の取得で最低2回 API を呼びます。30秒間隔では1件あたり約240回/時（ページネーションと通知の更新分は別）となり、複数 PR の同時待機では API のレート制限に注意が必要です。必要に応じて `ci_poll_interval_seconds` を60秒以上に設定してください。レート制限を含む API エラーは自動再試行せず、Action を失敗させます。状態通知にも同じ API を使うため、制限中は通知も失敗する場合があります。その場合は Actions のログを確認し、制限が解除されてから再依頼してください。

呼び出し元のジョブに `actions: read` 権限を付けてください。Composite Action から呼び出し元の権限を追加することはできません。ランナーには Ruby と GitHub CLI が必要です（上記の `ubuntu-latest` にはインストール済みです）。`ci_workflow` を省略した場合は CI 待機をスキップし、状態通知と PR の最新状態の確認を行ってレビューします。

## テスト

```sh
ruby claude-code/pr-review-on-label/ci_gate_test.rb
```

GitHub API 呼び出しと時刻・待機をスタブし、CI 待機・通知スクリプトの状態遷移と API リクエストを検証します。API への接続や Claude の起動は行いません。

PR の `Claude Review Tests` では GitHub runner 上でもローカルの Composite Action を読み込み、CI 対象外による失敗と状態通知まで実行します。GitHub CLI はスタブに差し替え、実 API と Claude は呼びません。状態通知の記録を検証するため、Action の読み込み自体に失敗した場合はテストが失敗します。
