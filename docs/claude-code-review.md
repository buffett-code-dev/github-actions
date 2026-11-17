# Claude Code による PR レビュー

この文書は、buffett-code-dev の各リポジトリで動く Claude Code の PR レビューについて、設定ファイルの場所と変更方法を説明します。

## 構成

Claude Code の PR レビューは、次の2種類のファイルで設定します。

| ファイル | リポジトリ | 記述する内容 |
| --- | --- | --- |
| Composite Action の `action.yml` | github-actions | 使用するモデル、`anthropics/claude-code-action` のバージョン、ラベルで起動したときのプロンプト |
| 呼び出し元のワークフロー | 各リポジトリの `.github/workflows/` | 起動条件、ジョブの権限、Composite Action への入力 |

呼び出し元のワークフローは、Composite Action を `@main` で参照します。そのため、github-actions の main ブランチに変更をマージすると、次回の実行から全リポジトリに反映されます。各リポジトリへのコミットは必要ありません。

## 起動方法

Claude Code の PR レビューには、2つの起動方法があります。起動方法ごとに、使用する Composite Action が異なります。

| 起動方法 | Composite Action | 呼び出し元のワークフローのファイル名の例 |
| --- | --- | --- |
| PR や Issue に `@claude` を含むコメントを投稿する | [`claude-code/pr-review`](https://github.com/buffett-code-dev/github-actions/tree/main/claude-code/pr-review) | `claude.yml` |
| PR に `claude-review` ラベルを付与する | [`claude-code/pr-review-on-label`](https://github.com/buffett-code-dev/github-actions/tree/main/claude-code/pr-review-on-label) | `claude-review-on-label.yml`、`claude-review.yml` |

呼び出し元のワークフローのファイル名は、リポジトリによって異なります。リポジトリが使用している Composite Action は、そのリポジトリの `.github/workflows/` で `buffett-code-dev/github-actions/claude-code/` を検索すると確認できます。

### `@claude` を含むコメントの投稿

`claude-code/pr-review` は、PR や Issue に `@claude` を含むコメントが投稿されたときに起動します。対象となるイベント（コメント、レビューコメント、レビュー、Issue の本文）は、呼び出し元のワークフローの `on` と `if` で指定します。

この Composite Action はプロンプトを指定していません。Claude は、`@claude` を含むコメントの内容を指示として扱います。リポジトリ固有のレビュー観点を Claude に伝える場合は、そのリポジトリの `CLAUDE.md` に記述します。Claude Code は、作業ディレクトリにある `CLAUDE.md` を読み込むためです。

### `claude-review` ラベルの付与

`claude-code/pr-review-on-label` は、PR に `claude-review` ラベルが付与されたときに起動します。対象は、同じリポジトリのブランチから作成された PR です。フォークから作成された PR は対象外です。

この Composite Action は、`action.yml` の `prompt` でレビューの内容を指定しています。

- Claude は、不具合、回帰、テスト不足を優先して確認します。
- Claude は、レビュー結果を PR のコメント1件として投稿します。コメントの冒頭には、`pass`、`changes_requested`、`needs_human` のいずれかを記載します。
- Claude が実行できるコマンドは、`gh pr view`、`gh pr diff`、`gh pr comment` に限定しています（`claude_args` の `--allowedTools`）。Claude はコードの変更、コミット、マージを行いません。

呼び出し元のワークフローでは、次の入力を指定できます。各入力の詳細は、[pr-review-on-label の README](https://github.com/buffett-code-dev/github-actions/blob/main/claude-code/pr-review-on-label/README.md) を参照してください。

| 入力 | 指定したときの動作 |
| --- | --- |
| `ci_workflow` | Claude を起動する前に、指定したワークフローが対象コミットで成功していることを確認します。成功していない場合は、Claude を起動せずに失敗します。 |
| `self_merge_policy_path` | 指定したセルフマージガイドラインに基づいて、セルフマージの可否の判定をレビューコメントに追加します。 |

この Composite Action は、PR のベースコミットをチェックアウトして Claude を起動します。そのため、Claude が読み込む `CLAUDE.md` とセルフマージガイドラインは、PR による変更を含まない内容です。PR でこれらのファイルを変更しても、その PR のレビューには反映されません。

## 設定の変更方法

Claude Code の PR レビューの設定には、全リポジトリに共通する設定と、リポジトリごとの設定があります。どちらの設定を変更するかによって、編集するリポジトリが異なります。

### 全リポジトリに共通する設定

全リポジトリに共通する設定は、github-actions の `action.yml` に記述しています。

| 変更する設定 | 編集するファイル | 編集する箇所 |
| --- | --- | --- |
| 使用するモデル | `claude-code/pr-review/action.yml`、`claude-code/pr-review-on-label/action.yml` | `claude_args` の `--model` |
| `anthropics/claude-code-action` のバージョン | `claude-code/pr-review/action.yml`、`claude-code/pr-review-on-label/action.yml` | `uses: anthropics/claude-code-action@...` |
| ラベルで起動したときのレビュー観点と出力形式 | `claude-code/pr-review-on-label/action.yml` | `prompt` |

モデルと `anthropics/claude-code-action` のバージョンは、2つの `action.yml` にそれぞれ記述しています。どちらかを変更するときは、もう一方も同じ値にそろえるかを確認してください。

### リポジトリごとの設定

リポジトリごとの設定は、各リポジトリのファイルに記述しています。

| 変更する設定 | 編集するファイル | 編集する箇所 |
| --- | --- | --- |
| リポジトリ固有のレビュー観点 | `CLAUDE.md` | - |
| 起動条件、ジョブの権限 | 呼び出し元のワークフロー | `on`、`if`、`permissions` |
| レビューの前に成功を確認する CI | 呼び出し元のワークフロー | `with` の `ci_workflow` |
| セルフマージの判定に使うガイドライン | 呼び出し元のワークフロー | `with` の `self_merge_policy_path` |

## github-actions の変更時の注意

`pr-review-on-label` の CI 確認処理には、テスト（`claude-code/pr-review-on-label/ci_gate_test.rb`）があります。このテストは、`claude-code/pr-review-on-label/` を変更した PR で自動的に実行されます。一方、プロンプトとモデルの変更を検証する自動テストはありません。プロンプトやモデルを変更したときは、マージ後にいずれかのリポジトリでレビューを起動し、結果を確認してください。

## リポジトリへの導入

リポジトリに Claude Code の PR レビューを導入する手順は、次のとおりです。

1. 呼び出し元のワークフローを、リポジトリの `.github/workflows/` に追加します。ワークフローの例は、各 Composite Action の README に記載しています。
2. `claude-review` ラベルで起動する場合は、リポジトリに `claude-review` ラベルを作成します。

Anthropic の API キーは、Organization secrets の `ANTHROPIC_API_KEY` を使用します。Organization secrets を使用できないリポジトリでは、リポジトリの secrets に同じ名前で登録してください。
