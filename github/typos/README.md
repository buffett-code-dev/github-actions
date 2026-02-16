# Typos Check

コードベース内のタイポ（typo）をチェックする composite action です。
内部的に [crate-ci/typos](https://github.com/crate-ci/typos) を使用しています。

## 使用方法

```yaml
steps:
  - uses: actions/checkout@v6

  - name: Check typos
    uses: buffett-code-dev/github-actions/github/typos@main
```

## パラメータ

| パラメータ | 説明 | 必須 | デフォルト |
|-----------|------|------|-----------|
| `files` | チェックするファイルまたはパターン | No | (全ファイル) |
| `config` | カスタム設定ファイルのパス | No | - |
| `isolated` | 暗黙的な設定ファイルを無視する | No | `false` |
| `write-changes` | 修正をディスクに書き込む（コミットはしない） | No | `false` |

## 使用例

### 基本的な使用

```yaml
- uses: buffett-code-dev/github-actions/github/typos@main
```

### 特定のディレクトリのみチェック

```yaml
- uses: buffett-code-dev/github-actions/github/typos@main
  with:
    files: src/
```

### カスタム設定ファイルを使用

```yaml
- uses: buffett-code-dev/github-actions/github/typos@main
  with:
    config: .typos.toml
```
