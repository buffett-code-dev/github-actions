# aws/credentials

AWS認証情報を設定するComposite Actionです。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/aws/credentials@main
  with:
    role_to_assume: arn:aws:iam::123456789012:role/GitHubActionsRole
    aws_region: ap-northeast-1
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `role_to_assume` | ✓ | - | 引き受けるIAMロールのARN |
| `aws_region` | | `ap-northeast-1` | AWSリージョン |

## 使用例

### 基本的な使用方法

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

      - name: AWS CLIコマンドを実行
        run: aws s3 ls
```

### 複数リージョンでの使用

```yaml
jobs:
  deploy:
    strategy:
      matrix:
        region: [ap-northeast-1, us-east-1]
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: buffett-code-dev/github-actions/aws/credentials@main
        with:
          role_to_assume: ${{ secrets.AWS_ROLE_ARN }}
          aws_region: ${{ matrix.region }}
```

## 前提条件

- GitHub ActionsでOIDC認証が設定されていること
- IAMロールにGitHubからのOIDCトークン信頼関係が設定されていること
- ワークフローに`id-token: write`権限が付与されていること
