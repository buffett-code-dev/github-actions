# serverless/python-setup

Python runtime環境でServerless Frameworkを使用するためのセットアップアクションです。

## 概要

このアクションは、Python環境でServerless Frameworkとserverless-python-requirementsプラグインを使用するための特殊なセットアップを行います。公式の`serverless/github-action`はPython runtimeを持たないため、Python 3.xコンテナ内でNode.jsをセットアップしてServerlessを実行する必要があります。

## 背景

- `serverless/github-action@v2`はPython runtimeを持たないため、`serverless-python-requirements`プラグインが動作しません
- Serverless Frameworkは廃止が決まっているため、安定したバージョンをハードコードして使用します
- 参考: [project-management#617](https://github.com/buffett-code-dev/project-management/issues/617), [project-management#214](https://github.com/buffett-code-dev/project-management/issues/214)

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/serverless/python-setup@main
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `node-version` | | `20` | セットアップするNode.jsのバージョン |
| `serverless-version` | | `2.72.4` | Serverless Frameworkのバージョン |
| `serverless-prune-plugin-version` | | `1.6.1` | serverless-prune-pluginのバージョン |
| `serverless-python-requirements-version` | | `5.4.0` | serverless-python-requirementsのバージョン |

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
        run: npx serverless deploy
```

### カスタムバージョンの指定

```yaml
- uses: buffett-code-dev/github-actions/serverless/python-setup@main
  with:
    node-version: '18'
    serverless-version: '2.72.0'
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
        run: npx serverless deploy --stage production
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
        run: npx serverless deploy --stage ${{ matrix.stage }}
```

## インストールされるパッケージ

このアクションは以下のnpmパッケージをインストールします:

- `serverless` - Serverless Framework本体
- `serverless-prune-plugin` - 古いLambdaバージョンを自動削除するプラグイン
- `serverless-python-requirements` - Pythonの依存関係を自動的にパッケージングするプラグイン

## 前提条件

- Python 3.x環境 (通常はコンテナで指定)
- serverless.ymlがリポジトリに存在すること
- AWS認証が完了していること (デプロイする場合)

## 注意事項

- Serverless Frameworkを利用したデプロイは廃止予定のため、将来的には別のデプロイ方法への移行を検討してください
- `--ignore-scripts`フラグを使用してnpmインストールのセキュリティリスクを軽減しています
