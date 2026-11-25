# Claude PR Review on Label 2（Agent SDK 実験版）

既存の `pr-review-on-label` を残して比較できる、Agent SDK 版のラベル起動レビューです。`pr-review` と `pr-review-on-label` は引き続き公式 Claude Code Action を使用します。参照先をこの Action に変更したジョブだけが SDK を使用します。

## 試し方

既存のワークフローを残したまま、次のような別ワークフローを追加できます。`claude-review-sdk` ラベルを利用先に作成してください。起動ラベルと concurrency の名前を既存版と分けることで、別々に起動・比較できます。

```yaml
name: Claude Agent SDK Review Experiment

on:
  pull_request:
    types: [labeled]

jobs:
  review:
    if: >-
      github.event.label.name == 'claude-review-sdk' &&
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    timeout-minutes: 30
    concurrency:
      group: claude-review-sdk-${{ github.event.pull_request.number }}
      cancel-in-progress: true
    permissions:
      contents: read
      pull-requests: write
      actions: read
    steps:
      - uses: buffett-code-dev/github-actions/claude-code/pr-review-on-label-2@main
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          github_token: ${{ github.token }}
          ci_workflow: ci.yml
```

この PR をマージする前に試す場合は、`@main` を PR のブランチ名またはコミット SHA に変更してください。利用する API キーは `anthropic_api_key` で指定します。既存版の Secret を変更する必要はありません。キーのローテーションは行いません。

## 入力

| 入力 | 必須 | 説明 |
| --- | --- | --- |
| `anthropic_api_key` | はい | Agent SDK が使用する Anthropic API キー |
| `github_token` | はい | PR の読み取りとレビューコメントの投稿に使うジョブの GitHub トークン |
| `ci_workflow` | いいえ | 成功を確認する `pull_request` ワークフローのファイル名（例: `ci.yml`）または ID。既定値は空文字列（確認なし） |
| `ci_wait_timeout_seconds` | いいえ | CI 完了の最大待機秒数。正の整数、既定値 `600`（10分） |
| `ci_start_timeout_seconds` | いいえ | 対象 CI が未作成の場合の開始猶予秒数。正の整数、既定値 `300`（5分） |
| `ci_poll_interval_seconds` | いいえ | CI の確認間隔秒数。正の整数、既定値 `30` |
| `ci_base_branches` | いいえ | CI の対象ベースブランチのカンマ区切り一覧。既定値は空文字列（制限なし） |
| `self_merge_policy_path` | いいえ | ベースコミットにあるセルフマージガイドラインのリポジトリ相対パス。既定値は空文字列 |


## 既存版との共通点と差分

レビュー観点・判定ラベル・セルフマージ判定の指示は既存版を引き継ぎ、SDK の読み取りツールと投稿方法に必要な部分だけを変更しています。システムプロンプトは `claude_code` 標準プリセットに SDK の操作説明だけを追加します。

CI 待ち・開始猶予・状態通知・セルフマージの事前判定は[既存版の説明](../pr-review-on-label/README.md)を参照してください。CI 待ちと通知は既存の `review_status.rb` を再利用し、SDK の正常終了後にスクリプトがレビュー結果を1件投稿します。人間のユーザーと Devin が付与したラベルを許可し、その他の bot と fork PR は拒否します。

SDK に与えるのは対象リポジトリの固定した base／head の読み取りツールだけです。base の `CLAUDE.md`・`AGENTS.md` と参照先の規約を読み、リポジトリの設定や hooks、シェル、コード変更ツールは使用しません。投稿直前に PR の head/base SHA・ベースブランチ・open 状態・ラベルを再確認します。

API エラー・モデルの拒否・空の結果・途中終了を成功として扱いません。SDK の会話全文はログに出しません。

runner には Python 3.10 以上と venv、Ruby、GitHub CLI が必要です（`ubuntu-latest` は対応）。SDK と間接依存は `requirements.txt` に固定し、一時ディレクトリの仮想環境にインストールします。

## 検証と依存更新

```sh
python3 -m venv /tmp/claude-agent-tests
/tmp/claude-agent-tests/bin/python -m pip install -r claude-code/pr-review-on-label-2/requirements.txt
/tmp/claude-agent-tests/bin/python -m unittest discover -s claude-code/pr-review-on-label-2 -v
ruby claude-code/pr-review-on-label/ci_gate_test.rb
```

実際のモデルの回答と月次クレジットによる課金は、実験用ワークフローで別途確認してください。実験を終了するときは、そのワークフローを外せば既存版の動作だけに戻ります。

依存を手動更新するときは `requirements.in` を変更し、固定版を再生成してください。

```sh
uv pip compile --universal --python-version 3.10 claude-code/pr-review-on-label-2/requirements.in -o claude-code/pr-review-on-label-2/requirements.txt
```
