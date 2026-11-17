# Claude Code による PR レビュー

この文書は、buffett-code-dev の各リポジトリで動く Claude Code の PR レビューについて、設定ファイルの場所と変更方法を説明します。各 Composite Action の入力と、リポジトリへの導入方法は、各 Composite Action の README を参照してください。

## 起動方法と Composite Action

Claude Code の PR レビューには、2つの起動方法があります。起動方法ごとに、使用する Composite Action が異なります。

| 起動方法 | Composite Action | 呼び出し元のワークフローのファイル名の例 |
| --- | --- |
| PR や Issue に `@claude` を含むコメントを投稿する | [`claude-code/pr-review`](https://github.com/buffett-code-dev/github-actions/tree/main/claude-code/pr-review) | `claude.yml` |
| PR に `claude-review` ラベルを付与する | [`claude-code/pr-review-on-label`](https://github.com/buffett-code-dev/github-actions/tree/main/claude-code/pr-review-on-label) | `claude-review-on-label.yml`、`claude-review.yml` |

呼び出し元のワークフローのファイル名は、リポジトリによって異なります。リポジトリが使用している Composite Action は、そのリポジトリの `.github/workflows/` で `buffett-code-dev/github-actions/claude-code/` を検索すると確認できます。

## 起動方法ごとの動作

### `@claude` を含むコメントを投稿したとき

`claude-code/pr-review` はプロンプトを指定していません。Claude は、`@claude` を含むコメントの内容と、リポジトリの `CLAUDE.md` の内容に従ってレビューします。

### `claude-review` ラベルを付与したとき

`claude-code/pr-review-on-label` は、`action.yml` の `prompt` でレビューの観点と出力形式を指定しています。Claude は、このプロンプトと、リポジトリの `CLAUDE.md` の内容に従ってレビューします。

この Composite Action は、PR のベースコミットで Claude を起動します。そのため、PR で `CLAUDE.md` やセルフマージガイドラインを変更しても、その PR のレビューには反映されません。

## 設定ファイルの場所と変更方法

Claude Code の PR レビューの設定には、全リポジトリに共通する設定と、リポジトリごとの設定があります。どちらの設定を変更するかによって、編集するリポジトリが異なります。

### 全リポジトリに共通する設定

全リポジトリに共通する設定は、github-actions の `action.yml` に記述しています。

| 変更する設定 | 編集するファイル |
| --- | --- |
| 使用するモデル | `claude-code/pr-review/action.yml`、`claude-code/pr-review-on-label/action.yml` |
| `anthropics/claude-code-action` のバージョン | `claude-code/pr-review/action.yml`、`claude-code/pr-review-on-label/action.yml` |
| ラベルで起動したときのレビュー観点と出力形式 | `claude-code/pr-review-on-label/action.yml` |

呼び出し元のワークフローは、Composite Action を `@main` で参照します。そのため、github-actions の main ブランチに変更をマージすると、全リポジトリに反映されます。プロンプトとモデルの変更を検証する自動テストはないため、マージ後にいずれかのリポジトリでレビューを起動し、結果を確認してください。

### リポジトリごとの設定

リポジトリごとの設定は、各リポジトリのファイルに記述しています。

| 変更する設定 | 編集するファイル |
| --- | --- |
| リポジトリ固有のレビュー観点 | `CLAUDE.md` |
| 起動条件、ジョブの権限、レビューの前に成功を確認する CI、セルフマージの判定に使うガイドライン | 呼び出し元のワークフロー |
