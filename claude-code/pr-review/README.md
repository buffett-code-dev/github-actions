# Claude PR Review

Claude Agent SDK を使用し、`@claude` の依頼に応じて PR をレビューしたり、Issue の質問に回答したりする Composite Action です。

## 使用方法

```yaml
name: Claude PR Assistant

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]

jobs:
  review:
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude')) ||
      (github.event_name == 'issues' && contains(github.event.issue.body, '@claude'))
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - uses: buffett-code-dev/github-actions/claude-code/pr-review@main
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ github.token }}
          allowed_bots: yamori-ai-integration
```

## 入力

| 入力 | 必須 | 既定値 | 説明 |
| --- | --- | --- | --- |
| `anthropic_api_key` | はい | なし | Agent SDK が使用する Anthropic API キー |
| `allowed_bots` | いいえ | 空文字列 | 許可する bot のカンマ区切り一覧。`[bot]` の有無と `*` のワイルドカードに対応 |
| `checkout_fetch_depth` | いいえ | `1` | ベース側をチェックアウトするときの fetch-depth |
| `github_token` | いいえ | 空文字列 | GitHub の読み取り・回答の投稿に使うトークン。省略時は従来どおり OIDC で Claude GitHub App のトークンを取得 |

人からの依頼はリポジトリへの write・maintain・admin 権限がある場合だけ実行します。bot は `allowed_bots` に一致する場合だけ実行します。

## レビューの動作

公式 `anthropics/claude-code-action` を介さず、[共通の SDK 実行スクリプト](../agent/) を起動します。依頼コメント、Issue／PR の本文、過去のコメント、PR の差分と行コメントを取得して渡します。モデルは `claude-sonnet-5` です。

`@claude` の依頼本文をそのまま指示として渡します。システムプロンプトは公式 Action と同じ `claude_code` 標準プリセットに SDK の操作説明だけを追加し、レビュー観点・回答言語・`pass` 等の出力形式は共通処理から追加しません。

エージェントは対象リポジトリのファイルとディレクトリを、固定した base／head コミットから読み取れます。base の `CLAUDE.md`・`AGENTS.md` と参照先の規約も確認するよう指示します。シェル、ファイルの変更、GitHub への書き込みツールは与えません。コード修正やコミットを依頼しても実行しません。

SDK が正常終了し、空でない回答を返した場合だけ、スクリプトがコメントを1件投稿します。PR は投稿直前に head SHA・base SHA・ベースブランチ・open 状態を再確認し、変更があれば失敗として終了します。API エラー・モデルの拒否・途中終了は成功扱いにせず、レビュー結果を投稿しません。

## GitHub 認証と必要な環境

`github_token` を渡す場合は、上の例のようにコメント投稿先への write 権限を付けます。`id-token: write` は不要です。投稿者は渡したトークンに対応するユーザー（ジョブのトークンなら `github-actions[bot]`）です。

`github_token` を省略する既存の設定も利用できます。この場合は Claude GitHub App のインストールと `id-token: write` が必要です。OIDC を Anthropic の GitHub App トークン交換エンドポイントで交換し、終了時に取得したトークンを失効させます。

runner には Python 3.10 以上・venv・GitHub CLI が必要です。`ubuntu-latest` にはインストール済みです。SDK は `$RUNNER_TEMP` の仮想環境に固定バージョンでインストールします。

API キーは既存の `ANTHROPIC_API_KEY` Secret を使用します。キーの切り替えや残高不足時のフォールバックは行いません。SDK の会話全文はログに出しません。
