# github/amazon-ecr-login

Amazon ECRへのログインを行うComposite Actionです。`aws-actions/amazon-ecr-login`のラッパーで、チーム全体で統一されたECRログイン方法を提供します。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/github/amazon-ecr-login@main
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `registry-type` | | `private` | ECRレジストリのタイプ (`private` または `public`) |
| `registries` | | - | ログインするAWSアカウントIDのカンマ区切りリスト (privateレジストリのみ) |
| `mask-password` | | `true` | ログでDockerパスワードをマスクするか |
| `http-proxy` | | - | AWS API呼び出しに使用するHTTPプロキシ |

## 出力

| 名前 | 説明 |
|------|------|
| `registry` | ECRレジストリURI |

## 使用例

### 基本的な使用方法 (プライベートECR)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: buffett-code-dev/github-actions/aws/credentials@main
        with:
          role_to_assume: ${{ secrets.AWS_ROLE_ARN }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: buffett-code-dev/github-actions/github/amazon-ecr-login@main

      - name: Build and push
        run: |
          docker build -t ${{ steps.login-ecr.outputs.registry }}/my-app:latest .
          docker push ${{ steps.login-ecr.outputs.registry }}/my-app:latest
```

### パブリックECRへのログイン

```yaml
- name: Login to Amazon ECR Public
  uses: buffett-code-dev/github-actions/github/amazon-ecr-login@main
  with:
    registry-type: public
```

### 複数のAWSアカウントのECRにログイン

```yaml
- name: Login to multiple ECR registries
  uses: buffett-code-dev/github-actions/github/amazon-ecr-login@main
  with:
    registries: "123456789012,987654321098"
```

### docker/buildアクションとの組み合わせ

```yaml
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: buffett-code-dev/github-actions/aws/credentials@main
        with:
          role_to_assume: ${{ secrets.AWS_ROLE_ARN }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: buffett-code-dev/github-actions/github/amazon-ecr-login@main

      - uses: buffett-code-dev/github-actions/docker/build@main
        with:
          file: ./Dockerfile
          image: ${{ steps.login-ecr.outputs.registry }}/my-app
          push: true
```

## 従来の書き方からの移行

```yaml
# 従来の書き方
- uses: aws-actions/amazon-ecr-login@v2

# 新しい書き方
- uses: buffett-code-dev/github-actions/github/amazon-ecr-login@main
```

## 前提条件

- AWS認証が完了していること (通常は`aws/credentials`アクションを先に実行)
- ワークフローに`id-token: write`権限が付与されていること
- 使用するIAMロールにECRへのアクセス権限があること

## 利点

- チーム全体で統一されたECRログイン方法
- アップストリームのバージョン管理を一元化
- 将来的なカスタマイズや拡張が容易
