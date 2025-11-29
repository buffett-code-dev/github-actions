# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの概要

このリポジトリは、GitHub Actions用の再利用可能なComposite Actionsを提供するライブラリです。
buffett-code-devプロジェクト内の複数のリポジトリで共通的に使用されるワークフローをまとめています。

## アーキテクチャ

### ディレクトリ構造

リポジトリは機能別に3つのカテゴリに分かれています:

```
.
├── aws/                    # AWS関連のアクション
│   ├── credentials/        # AWS認証設定
│   └── lambda_function_update/  # Lambda関数更新
├── docker/                 # Docker関連のアクション
│   └── build/              # Dockerビルド・プッシュ
└── github/                 # GitHub関連のアクション
    ├── dependabot-auto-merge/  # Dependabot自動マージ
    └── label-stale-items/      # 古いissueへのラベル付与
```

### Composite Actionsの仕様

各アクションは`action.yml`ファイルで定義され、以下の構造を持ちます:
- `name`: アクション名
- `inputs`: 入力パラメータ(required/default値の定義)
- `runs`: 実行内容(using: compositeを使用)

### 重要な実装詳細

#### AWS関連
- **credentials**: デフォルトリージョンは`ap-northeast-1`
- **lambda_function_update**: イメージURIは`{image}:{tag}`形式で指定

#### Docker
- **build**:
  - `docker/metadata-action`でタグを動的生成(branch/tag/PR参照)
  - GitHub Actionsキャッシュ(`type=gha`)を使用してビルド高速化
  - `provenance: false`でprovenanceアーティファクトを無効化

#### GitHub
- **dependabot-auto-merge**:
  - デフォルトで`semver-patch`更新のみ自動マージ
  - `dependabot/fetch-metadata`でメタデータ取得後、条件判定
- **label-stale-items**:
  - デフォルトで60日間更新なしでstaleラベル付与
  - PR用の設定は無効(`days-before-pr-stale: -1`)

## 開発時の注意点

### 新しいアクションの追加
1. 適切なカテゴリディレクトリ(aws/docker/github)に配置
2. `action.yml`を作成し、必ず以下を定義:
   - `name`
   - `inputs`(required/defaultを明示)
   - `runs.using: composite`
3. `README.md`を作成して使用方法を記載
4. 必要に応じて、　`.github/dependabot.yml`に新しいディレクトリを追加してDependabot管理下に配置

### action.ymlの変更時の重要な注意事項
**`action.yml`を変更した場合、必ず同じディレクトリ内の`README.md`も更新すること**

- パラメータの追加・削除・変更時は、READMEのパラメータ表を更新
- デフォルト値を変更した場合も、READMEに反映
- 使用例が古くなっていないか確認
- 各アクションは`action.yml`と`README.md`が常に同期している必要がある

### Dependabot設定
- 全てのアクションディレクトリが`.github/dependabot.yml`で管理されている
- 新しいアクションを追加した場合、必ずdependabot.ymlの修正が必要ないか確認すること
