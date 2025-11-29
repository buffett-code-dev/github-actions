# aws/lambda_function_update

Lambda関数のDockerイメージを更新するComposite Actionです。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/aws/lambda_function_update@main
  with:
    function_name: my-lambda-function
    image: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-image
    tag: latest
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `function_name` | ✓ | - | Lambda関数名 |
| `image` | ✓ | - | コンテナイメージのURI (タグを除く) |
| `tag` | | `main` | イメージタグ |

## 使用例

### ECRからのデプロイ

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - uses: buffett-code-dev/github-actions/aws/credentials@main
        with:
          role_to_assume: ${{ secrets.AWS_ROLE_ARN }}

      - name: ECRにログイン
        run: |
          aws ecr get-login-password --region ap-northeast-1 | \
            docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}

      - uses: buffett-code-dev/github-actions/docker/build@main
        with:
          file: ./Dockerfile
          image: ${{ secrets.ECR_REGISTRY }}/my-app
          push: true

      - uses: buffett-code-dev/github-actions/aws/lambda_function_update@main
        with:
          function_name: my-lambda
          image: ${{ secrets.ECR_REGISTRY }}/my-app
```

### 特定のタグでデプロイ

```yaml
- uses: buffett-code-dev/github-actions/aws/lambda_function_update@main
  with:
    function_name: my-lambda
    image: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-image
    tag: v1.2.3
```

### ブランチ名をタグとして使用

```yaml
- uses: buffett-code-dev/github-actions/aws/lambda_function_update@main
  with:
    function_name: my-lambda-${{ github.ref_name }}
    image: ${{ secrets.ECR_REGISTRY }}/my-app
    tag: ${{ github.ref_name }}
```

## 前提条件

- AWS認証が完了していること (通常は`aws/credentials`アクションを先に実行)
- Lambda関数が既に作成されていること
- Lambda関数がコンテナイメージタイプであること
- 指定したイメージとタグがECRに存在すること
