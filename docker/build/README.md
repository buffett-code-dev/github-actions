# docker/build

Dockerイメージをビルドし、オプションでレジストリにプッシュするComposite Actionです。GitHub Actionsキャッシュを使用してビルドを高速化します。

## 使用方法

```yaml
- uses: buffett-code-dev/github-actions/docker/build@main
  with:
    file: ./Dockerfile
    image: ghcr.io/buffett-code-dev/my-app
    push: true
```

## パラメータ

| 名前 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `file` | ✓ | - | Dockerfileのパス |
| `image` | ✓ | - | イメージ名 (レジストリを含む) |
| `tag` | | (自動生成) | 固定タグ。指定しない場合は自動生成 |
| `context` | | `.` | ビルドコンテキストのパス |
| `push` | | `false` | イメージをレジストリにプッシュするか |

## タグの自動生成ルール

`tag`パラメータを指定しない場合、以下のルールでタグが自動生成されます:

- **ブランチプッシュ**: ブランチ名 (例: `main`, `develop`)
- **タグプッシュ**: タグ名 (例: `v1.0.0`)
- **プルリクエスト**: `pr-{番号}` (例: `pr-123`)
- **常に**: `latest`

## 使用例

### 基本的なビルド (プッシュなし)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: buffett-code-dev/github-actions/docker/build@main
        with:
          file: ./Dockerfile
          image: my-app
          push: false
```

### GitHub Container Registryへのプッシュ

```yaml
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: buffett-code-dev/github-actions/docker/build@main
        with:
          file: ./Dockerfile
          image: ghcr.io/${{ github.repository }}
          push: true
```

### Amazon ECRへのプッシュ

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

      - name: ECRにログイン
        run: |
          aws ecr get-login-password --region ap-northeast-1 | \
            docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}

      - uses: buffett-code-dev/github-actions/docker/build@main
        with:
          file: ./Dockerfile
          image: ${{ secrets.ECR_REGISTRY }}/my-app
          push: true
```

### 固定タグの指定

```yaml
- uses: buffett-code-dev/github-actions/docker/build@main
  with:
    file: ./Dockerfile
    image: ghcr.io/buffett-code-dev/my-app
    tag: v1.2.3
    push: true
```

### カスタムビルドコンテキスト

```yaml
- uses: buffett-code-dev/github-actions/docker/build@main
  with:
    file: ./docker/Dockerfile.prod
    context: ./app
    image: my-app
    push: true
```

### マルチアーキテクチャビルド (応用)

```yaml
- uses: docker/setup-qemu-action@v3

- uses: buffett-code-dev/github-actions/docker/build@main
  with:
    file: ./Dockerfile
    image: ghcr.io/buffett-code-dev/my-app
    push: true
```

## 機能

- **GitHub Actionsキャッシュ**: ビルドレイヤーをキャッシュして再ビルドを高速化
- **自動タグ生成**: ブランチ/タグ/PR番号から適切なタグを自動生成
- **Buildxサポート**: Docker Buildxを使用した高度なビルド機能

## 前提条件

- イメージをプッシュする場合は、事前にレジストリへのログインが必要
- プッシュ先のレジストリへのアクセス権限が必要
