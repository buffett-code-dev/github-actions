# serverless/python-setup

Python runtime環境でServerless Frameworkを使用するためのセットアップアクションです。

## 概要

このアクションは、Python環境でServerless Frameworkとserverless-python-requirementsプラグインを使用するための特殊なセットアップを行います。公式の`serverless/github-action`はPython runtimeを持たないため、Python 3.xコンテナ内でNode.jsをセットアップしてServerlessを実行する必要があります。

依存パッケージ (`serverless` / `serverless-prune-plugin` / `serverless-python-requirements`) は本アクション直下の `package.json` / `package-lock.json` で固定し、`npm ci` でインストールします。これにより、`safe-chain` の minimum package age チェックで transitive dependency の最新版を毎回引いてブロックされる事象を防ぎます。Serverless Framework は廃止予定のため、本アクションの依存は **塩漬け** とし Dependabot の対象外にしています (必要に応じて廃止までの間に手動更新します)。

## 背景

- `serverless/github-action`はPython runtimeを持たないため、`serverless-python-requirements`プラグインが動作しません
- Serverless Frameworkは廃止が決まっているため、安定したバージョンをハードコードして使用します

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/serverless/python-setup@main
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `node-version` | | `20` | セットアップするNode.jsのバージョン |

依存パッケージのバージョンは本アクション内の `package-lock.json` で固定されているため、呼び出し側で指定する必要はありません。

## 使用例

### 基本的な使用方法

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: python:3.13
    steps:
      - uses: actions/checkout@v4

      - uses: buffett-code-dev/github-actions/serverless/python-setup@main

      - name: Deploy with Serverless
        run: node_modules/.bin/serverless deploy
```

### AWS認証と組み合わせた完全なデプロイ例

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: python:3.13
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: buffett-code-dev/github-actions/aws/credentials@main
        with:
          role_to_assume: ${{ secrets.AWS_ROLE_ARN }}

      - uses: buffett-code-dev/github-actions/serverless/python-setup@main

      - name: Install Python dependencies
        run: pip install -r requirements.txt

      - name: Deploy to AWS Lambda
        run: node_modules/.bin/serverless deploy --stage production
```

### 複数ステージへのデプロイ

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    container:
      image: python:3.13
    strategy:
      matrix:
        stage: [dev, staging, production]
    steps:
      - uses: actions/checkout@v4

      - uses: buffett-code-dev/github-actions/aws/credentials@main
        with:
          role_to_assume: ${{ secrets.AWS_ROLE_ARN }}

      - uses: buffett-code-dev/github-actions/serverless/python-setup@main

      - name: Deploy to ${{ matrix.stage }}
        run: node_modules/.bin/serverless deploy --stage ${{ matrix.stage }}
```

## インストールされるパッケージ

このアクションは以下のnpmパッケージを `package-lock.json` で固定したバージョンでインストールします:

- `serverless` - Serverless Framework本体
- `serverless-prune-plugin` - 古いLambdaバージョンを自動削除するプラグイン
- `serverless-python-requirements` - Pythonの依存関係を自動的にパッケージングするプラグイン

インストール後、`node_modules` を呼び出し側ワークスペースのルートにシンボリックリンクするため、`node_modules/.bin/serverless` で実行できます。

## 前提条件

- Python 3.x環境 (通常はコンテナで指定)
- serverless.ymlがリポジトリに存在すること
- AWS認証が完了していること (デプロイする場合)

## 注意事項
- `npm install` の前に `safe-chain setup-ci` を実行してセキュリティリスクを軽減しています
- `package-lock.json` で依存を固定しているため、`safe-chain` の minimum package age チェックは transitive dependency の最新版に対しては発動しません
- `serverless@3` 系の transitive dependency に既知の脆弱性が含まれますが、これまで本番運用していた組み合わせと同じです。詳細と OSV-Scanner 抑制理由は `osv-scanner.toml` を参照してください。serverless 廃止時に当該 lockfile と `osv-scanner.toml` ごと削除します
- Serverless Frameworkを利用したデプロイは廃止予定のため、将来的には別のデプロイ方法への移行を検討してください
- `--ignore-scripts`フラグを使用してnpmインストールのセキュリティリスクを軽減しています
