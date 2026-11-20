# Agent SDK の共通実行処理

`pr-review` と `pr-review-on-label` が `run.sh` を起動し、`review.py` が Claude Agent SDK を直接使用します。API キーは `ANTHROPIC_API_KEY` の1本だけです。

- `requirements.txt`: SDK と同梱 CLI のバージョンを固定。Dependabot の pip 更新対象。
- `review.py`: 依頼者確認、Issue／PR の文脈取得、SDK 実行、正常終了後のコメント投稿。
- `test_review.py`: イベント解釈、権限、残高不足を含む SDK の失敗、投稿前の SHA・ラベル確認を検証。

SDK に渡すのは、対象リポジトリの固定した base／head コミットに対する読み取り専用 MCP ツールです。通常のファイル・シェルツールやリポジトリの hooks は使用しません。GitHub 認証は親プロセスが管理し、SDK の子プロセスには GitHub トークンと OIDC トークンを渡しません。

GitHub への書き込みは正常終了した回答のコメント投稿だけです。SDK の `subtype=success` だけでは成功と判断せず、`is_error` と回答の有無も確認します。PR が更新・クローズされた場合やラベルが外れた場合は投稿しません。

## 検証

```sh
python3 -m venv /tmp/claude-agent-tests
/tmp/claude-agent-tests/bin/python -m pip install -r claude-code/agent/requirements.txt
/tmp/claude-agent-tests/bin/python -m unittest discover -s claude-code/agent -v
```

テストは API を呼ばず、SDK の実際のメッセージ型と入力データで判定処理を確認します。実際のレビュー結果、GitHub App の OIDC 認証と月次クレジットによる課金は、利用先で別途確認してください。
