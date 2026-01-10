# GitHub Actions

`buffett-code-dev`プロジェクトで使用する再利用可能なComposite Actionsのライブラリです。

## ディレクトリ構成

```
.
├── aws/                    # AWS関連のアクション
├── claude/                 # Claude AI関連のアクション
├── docker/                 # Docker関連のアクション
├── github/                 # GitHub関連のアクション
└── serverless/             # Serverless Framework関連のアクション
```

各アクションは以下の構造で配置します:

```
{category}/{action-name}/
├── action.yml
└── README.md
```

各アクションは`action.yml`とその説明を記載した`README.md`をセットで配置します。

## 利用可能なアクション

- **[aws/credentials](aws/credentials/)** - AWS認証情報を設定
- **[aws/lambda_function_update](aws/lambda_function_update/)** - Lambda関数のDockerイメージを更新
- **[claude/pr-review](claude/pr-review/)** - Claude AIによるPRレビューとIssue対応
- **[docker/build](docker/build/)** - Dockerイメージのビルドとプッシュ
- **[github/amazon-ecr-login](github/amazon-ecr-login/)** - Amazon ECRへのログイン
- **[github/label-stale-items](github/label-stale-items/)** - 古いissueへのラベル付与
- **[github/dependabot-auto-merge](github/dependabot-auto-merge/)** - Dependabot PRの自動マージ
- **[serverless/python-setup](serverless/python-setup/)** - Python環境でのServerless Frameworkセットアップ

各アクションの詳細な使用方法は、それぞれのディレクトリ内のREADMEを参照してください。

## 新しいアクションの追加

新しいアクションを追加する際は、以下の手順に従ってください:

1. 適切なカテゴリディレクトリ(`aws`/`docker`/`github`等)を選択、または新しいカテゴリディレクトリを作成
2. カテゴリ配下に新しいアクション用のディレクトリを作成
3. `action.yml`を作成してアクションを定義
4. `README.md`を作成して使用方法を記載
5. `.github/dependabot.yml`に新しいディレクトリを追加

## セキュリティ

### OSV Scanner

このリポジトリでは[OSV Scanner](https://github.com/google/osv-scanner)を使用して脆弱性スキャンを実施しています。

- **実行タイミング**: プルリクエスト作成時
- **動作**: 脆弱性が検出された場合はPRチェックが失敗します
- **設定ファイル**: [.github/workflows/osv-scanner.yml](.github/workflows/osv-scanner.yml)

## メンテナンス

このリポジトリは[Dependabot](https://github.com/dependabot)により自動的に更新されます。

- 各アクションディレクトリが`.github/dependabot.yml`で管理されています
- 更新スケジュール: 毎週月曜日 (Asia/Tokyoタイムゾーン)
- パッチバージョン更新は自動マージされます ([dependabot-auto-merge](github/dependabot-auto-merge/)を使用)
