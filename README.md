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
tasks/windows_from_wsl.yml
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
| Ubuntu | pnpm / npm | `~/.npmrc` | `minimum-release-age` |
| Windows | pnpm / npm | `%USERPROFILE%\.npmrc` | `minimum-release-age` |
| Ubuntu | uv | `~/.config/uv/uv.toml` | `exclude-newer` |

### カスタマイズ可能な変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `develop_setting_npm_minimum_release_age` | `"7"` | pnpm / npm の最小リリース期間（日数） |
| `develop_setting_uv_exclude_newer` | `""` | uv の `exclude-newer` 日時（RFC 3339形式、空文字で無効） |

### uv の `exclude-newer` について

`exclude-newer` は静的な日時（例: `"2024-01-01T00:00:00Z"`）を指定します。  
指定した日時より後に公開されたパッケージはインストールされません。  
定期的にこの値を更新することで、ローリング方式のクールダウンとして機能します。

```yaml
vars:
  develop_setting_uv_exclude_newer: "2024-01-01T00:00:00Z"  # 例: RFC 3339 形式の固定日時を設定
```

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
| `CLAUDE.md` | 標準のグローバル指示文を含む、ユーザーレベルの Claude 向け指示ファイル |
| `settings.json` | Claude Code の設定（MCP サーバー設定を含む） |
| `~/.claude/hooks/` | `claude-plugins` の setup によりグローバル配置される hooks |
| `~/.claude/commands/` | `claude-plugins` の setup によりグローバル配置される commands |

### カスタマイズ可能な変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `develop_setting_claude_config_dir` | `~/.claude` | Claude 設定ディレクトリ（Ubuntu のみ） |
| `develop_setting_claude_plugins_repo_url` | `https://github.com/toshibe678/claude-plugins.git` | cloneする `claude-plugins` のリポジトリURL |
| `develop_setting_claude_plugins_linux_dir` | `~/git/claude-plugins` | Ubuntu での clone 先ディレクトリ |
| `develop_setting_claude_plugins_setup_options` | `--all --rules --hooks --commands --skills --global` | setup.sh 実行オプション |
| `develop_setting_windows_from_wsl_enabled` | `false` | WSLからWindowsホーム配下へ設定するモードを有効化 |
| `develop_setting_windows_from_wsl_mount_dir` | `/mnt/` | WSLでのWindowsマウント基点 |
| `develop_setting_windows_user_name` | `""` | 設定対象のWindowsユーザー名 |
| `develop_setting_windows_home_dir` | `/mnt/c/Users/{user}` | WSL経由設定時のWindowsホームパス |
| `develop_setting_windows_claude_config_dir` | `/mnt/c/Users/{user}/.claude` | WSL経由設定時のClaude設定パス |
| `develop_setting_claude_plugins_windows_wsl_dir` | `/mnt/c/Users/{user}/git/claude-plugins` | WSL経由設定時のclaude-plugins配置先 |

### `CLAUDE.md` の生成方針

この Role は、`CLAUDE.md` に以下の標準文面を常に含めます。

- 日本語での応答
- 結論ファースト、敬語、不要な前置きを避ける
- 経営判断 / 実務整理 / 技術判断を支援する役割
- `gh CLI` の利用方針
- シンプルさ・最小変更・検証重視の行動原則

### `settings.json` の生成方針

この Role は、`settings.json` を変数から組み立てず、テンプレートに固定定義した内容をそのまま配置します。

- ベースは [toshibe/.claude/settings.json](toshibe/.claude/settings.json) と [toshibe/.claude/settings.local.json](toshibe/.claude/settings.local.json) のマージ結果
- `env`、`sandbox`、`permissions`、`hooks`、`attribution` を標準設定として含む
- `permissions.allow` は両ファイルの許可設定を統合
- `hooks.PreToolUse` は Bash 用フックを1つの matcher にまとめて統合
- hook の `command` は `$CLAUDE_PROJECT_DIR` ではなく、ホーム配下の `~/.claude/hooks/` を参照する

### `claude-plugins` の配備方針

この Role は、`claude-plugins` を GitHub から clone し、`setup.sh` でグローバルインストールを実行します。

- 実行コマンド: `./setup.sh --all --rules --hooks --commands --skills --global`
- Ubuntu: `{{ ansible_env.HOME }}/git/claude-plugins` へ clone して実行
- Windows: Git Bash（`bash`）経由で `$HOME/git/claude-plugins` へ clone して実行
- `settings.json` は Ubuntu / Windows 共通で `$HOME/.claude/hooks/*.sh` を `bash` 経由で呼び出す前提

### WSL経由でWindows設定を適用する方法

Windowsホストへ WinRM 接続せず、WSL上のLinux実行から `/mnt/c/Users/...` に直接配置したい場合は、
次の変数を指定して `develop_setting_windows_from_wsl_enabled` を有効化します。

```yaml
- hosts: all
  gather_facts: true
  vars:
    develop_setting_windows_from_wsl_enabled: true
    develop_setting_windows_user_name: "your_windows_user"
  roles:
    - role: develop_setting
```

このモードでは `windows.yml` のOS判定分岐ではなく、`windows_from_wsl.yml` が実行されます。

### 設定例

```yaml
- hosts: all
  gather_facts: true
  roles:
    - role: develop_setting
```