# develop-settiong

Windows 11 と Ubuntu Server (24.04 / 26.04) 向けの共通設定をまとめた、Ansible Role のベースです。  
他の Playbook から `ansible-galaxy` 経由で取り込んで利用することを想定しています。

## この Issue の要約

- Windows 向け task と Linux(Ubuntu) 向け task を分離
- Windows は Windows 11 を対象
- Ubuntu は 24.04 / 26.04 を対象
- 他 Playbook から呼び出せる Role 構成を用意

## Role 構成

```text
defaults/main.yml
handlers/main.yml
meta/main.yml
tasks/main.yml
tasks/windows.yml
tasks/ubuntu.yml
templates/pre-commit-config.yaml.j2
templates/claude_CLAUDE.md.j2
templates/claude_settings.json.j2
```

## 使い方

`requirements.yml` 例:

```yaml
roles:
  - name: develop_setting
    src: https://github.com/toshibe678/develop-settiong.git
```

Playbook 例:

```yaml
- hosts: all
  gather_facts: true
  roles:
    - role: develop_setting
```

## サプライチェーン攻撃対策（パッケージマネージャークールダウン）

この Role は、新しく公開されたパッケージを一定期間インストールできないよう  
**クールダウン（最小リリース期間）** を各パッケージマネージャーに設定します。  
これにより、悪意のあるパッケージが公開直後に使用されるリスクを軽減します。

### 設定内容

| OS | 対象 | 設定ファイル | 設定キー |
|---|---|---|---|
| Ubuntu / Windows | pnpm / npm | `~/.npmrc` | `minimum-release-age` |
| Ubuntu | uv | `~/.config/uv/uv.toml` | `exclude-newer` |

### カスタマイズ可能な変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `develop_setting_npm_minimum_release_age` | `"7 days"` | pnpm / npm の最小リリース期間 |
| `develop_setting_uv_exclude_newer` | `""` | uv の `exclude-newer` 日時（RFC 3339形式、空文字で無効） |

### uv の `exclude-newer` について

`exclude-newer` は静的な日時（例: `"2024-01-01T00:00:00Z"`）を指定します。  
指定した日時より後に公開されたパッケージはインストールされません。  
定期的にこの値を更新することで、ローリング方式のクールダウンとして機能します。

```yaml
vars:
  develop_setting_uv_exclude_newer: "2025-06-20T00:00:00Z"  # 7日前の日時を設定
```

### GitHub Actions: Dependency Review

`.github/workflows/dependency-review.yml` により、プルリクエスト時に  
依存関係の脆弱性を自動チェックします（`moderate` 以上の重大度で失敗）。

### Dependabot 自動更新

`.github/dependabot.yml` により、npm および GitHub Actions の依存関係を  
週次で自動更新します（7日クールダウン付き）。

## セキュリティスキャン (semgrep + gitleaks)

この Role は、**semgrep** と **gitleaks** を使った自動セキュリティスキャンを  
**デフォルトユーザーのホームディレクトリ**にグローバル pre-commit フックとして設定します。

### 動作概要

1. `pre-commit` を pip 経由でインストール
2. `~/.pre-commit-config.yaml` にグローバル設定ファイルを配置  
   (semgrep と gitleaks の hooks を定義)
3. `~/.git-hooks/pre-commit` にフックスクリプトを配置
4. `git config --global core.hooksPath ~/.git-hooks` を設定

これにより、ユーザーが操作する **すべての Git リポジトリ** でコミット時に  
semgrep (静的解析) と gitleaks (シークレット検出) が自動実行されます。

### カスタマイズ可能な変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `develop_setting_security_hooks_dir` | `~/.git-hooks` | グローバルフックディレクトリ |
| `develop_setting_security_precommit_config` | `~/.pre-commit-config.yaml` | pre-commit 設定ファイルパス |
| `develop_setting_gitleaks_rev` | `v8.18.0` | gitleaks の revision |
| `develop_setting_semgrep_rev` | `v1.68.0` | semgrep の revision |

### 必要なコレクション

Ubuntu ターゲットで `community.general.git_config` モジュールを使用します。  
`requirements.yml` にコレクションを追加してください:

```yaml
collections:
  - name: community.general
```

### Windows の前提条件

Windows ターゲットには **Git for Windows** がインストール済みであることが必要です。  
Git for Windows には Git Bash が付属しており、git hooks は Git Bash 経由で実行されます。  
このため、フックスクリプトは `#!/bin/sh` の POSIX シェルスクリプトとして動作します。

## Claude Code ユーザーレベル設定

この Role は、ユーザーがどのディレクトリで Claude Code を起動しても設定が適用されるよう、  
**ホームディレクトリの `.claude` 以下** にユーザーレベルの設定を配置します。

| OS | 配置先 |
|---|---|
| Ubuntu | `~/.claude/` |
| Windows | `%USERPROFILE%\.claude\` |

### 配置されるファイル

| ファイル | 説明 |
|---|---|
| `CLAUDE.md` | ユーザーレベルの Claude 向け指示・メモリファイル |
| `settings.json` | Claude Code の設定（MCP サーバー設定を含む） |

### カスタマイズ可能な変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `develop_setting_claude_config_dir` | `~/.claude` | Claude 設定ディレクトリ（Ubuntu のみ） |
| `develop_setting_claude_md_content` | `""` | `CLAUDE.md` に追記するコンテンツ |
| `develop_setting_claude_mcp_servers` | `{}` | MCP サーバー設定（`mcpServers` キー） |
| `develop_setting_claude_settings_env` | `{}` | Claude Code に渡す環境変数 |
| `develop_setting_claude_settings_permissions` | `{}` | Claude Code のパーミッション設定 |

### 設定例

```yaml
- hosts: all
  gather_facts: true
  vars:
    develop_setting_claude_md_content: |
      ## プロジェクト共通ルール
      - コミットメッセージは日本語で書くこと
      - テストを必ず書くこと
    develop_setting_claude_mcp_servers:
      filesystem:
        command: npx
        args:
          - -y
          - "@modelcontextprotocol/server-filesystem"
          - /home/user/projects
    develop_setting_claude_settings_env:
      ANTHROPIC_MODEL: claude-opus-4-5
  roles:
    - role: develop_setting
```