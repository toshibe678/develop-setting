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

### 1. `requirements.yml` に Role と Collection を追加

```yaml
roles:
  - name: develop_setting
    src: https://github.com/toshibe678/develop-settiong.git

collections:
  - name: community.general
  - name: ansible.windows    # Windows ターゲットを使う場合
  - name: community.windows  # Windows ターゲットを使う場合
```

バージョンを固定したい場合は `version` を指定します:

```yaml
roles:
  - name: develop_setting
    src: https://github.com/toshibe678/develop-settiong.git
    version: main  # タグ / ブランチ / コミットハッシュを指定可能
```

### 2. `ansible-galaxy` で Role と Collection をインストール

```bash
ansible-galaxy install -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

### 3. Playbook から呼び出す

```yaml
- hosts: all
  gather_facts: true
  roles:
    - role: develop_setting
```

### 設定の適用先ユーザー（become / sudo 実行時の注意）

この Role は **SSH でログインしたユーザー**（sudo する前のユーザー）のホームディレクトリに
設定を配置します。Playbook 側で `become: true` を指定していても適用先は変わりません。

- Ubuntu タスクの冒頭で `become` を外した状態の `id -un` と `getent passwd` により、
  ログインユーザー名とそのホームディレクトリを検出し、
  `develop_setting_target_user` / `develop_setting_target_home` に格納します
- パッケージインストール（apt）のみ `become: true` で実行し、
  ホーム配下へ書き込むタスクはすべて `become: false` でログインユーザーとして実行します

`gather_facts` が become 配下で走ると `ansible_env.HOME` が `/root` を指すため、
これらの値ではなく上記の検出結果を使用しています。

## プロファイルと項目グループ（開発機とサーバーで切り替える）

`develop_setting_profile` で、開発機（`workstation`）とサーバー（`server`）の既定を切り替えます。
各グループは `develop_setting_<グループ>_enabled`（真偽値）で個別に上書きできます。真偽値でない値は、処理を始める前に失敗します。

| グループ | 内容 | workstation | server |
|---|---|---|---|
| `languages` | golang・nodejs・npm・gh・go-task（aptの標準パッケージ）、uv、pnpm、`~/.npmrc` | 有効 | 有効 |
| `cli_packages` | 共通CLI、python3-pip、`pip.conf` | 有効 | 有効 |
| `home_files` | `.bashrc`・`.bash_profile`・`.gitconfig`・`.profile`・`.bash_aliases`・`.gitignore_global` | 有効 | 有効 |
| `precommit` | pre-commit（gitleaks + semgrep） | 有効 | 有効 |
| `ai` | Claude Code・プラグイン・AI-DLC（bun を含む） | 有効 | 無効 |
| `cloud_credentials` | `.aws/config`・SSH鍵・`.ssh/config` | 有効 | 無効 |
| `repo_clones` | `~/git` 配下への個人リポジトリの clone | 有効 | 無効 |

### 主な変数

| 変数名 | 既定値 | 説明 |
|---|---|---|
| `develop_setting_profile` | `workstation` | `workstation` または `server` |
| `develop_setting_expected_user` | `""` | SSHログインユーザーがこの値と一致しなければ、何も変更せずに失敗する（空なら検査しない）。infra は `manage_user_name` を渡す |
| `develop_setting_language_packages` | `golang-go` `nodejs` `npm` `gh` | 言語とツールの apt パッケージ。外部のリポジトリ（PPA）と署名鍵は追加しない（版はOSの標準に従う） |
| `develop_setting_git_safe_directories` | `[]` | `.gitconfig` の `[safe]` に出力する一覧（`git config --add` は使わない） |
| `develop_setting_aws_config_src` / `develop_setting_ssh_private_key_src` | `""` | Vault 暗号化ファイルの**絶対パス**。`cloud_credentials` が有効なときは必須 |
| `develop_setting_git_clones` | 6リポジトリ | `repo_clones` が clone する一覧。作業ツリーに変更があるものは更新しない |

### 外部インストーラ（uv・pnpm・bun・Claude Code・AI-DLC）

`curl ... | sh` の形は使いません。`tasks/install_script.yml` が、一時ファイルへ `get_url`（証明書検証あり）で取得し、
ベンダーがチェックサムを公開している場合は `checksum` で検証してから実行します。取得は3回まで再試行し、
失敗したら取得先を含むメッセージで止めます。一時ファイルは成否にかかわらず削除します。
なお、Claude Code の日次更新の cron ジョブ（`ai` グループ）は `curl | bash` のままです（server では無効）。

### 動作環境とテスト

- ansible-core 2.16 以上、Ubuntu 24.04 / 26.04。collection は `community.general` と `ansible.posix` を使います。
- 検査: `ansible-playbook -i localhost, --syntax-check tests/syntax.yml` と `ansible-lint -c .ansible-lint`（CI: `.github/workflows/ansible-lint.yml`）。
- テスト用プレイ（ローカルで実行できます。ネットワークと sudo は不要）:

```bash
export ANSIBLE_HOME="$TMPDIR/ansible-home" ANSIBLE_LOCAL_TEMP="$TMPDIR/ansible-tmp" ANSIBLE_REMOTE_TMP="$TMPDIR/ansible-remote"
for t in validate profile_defaults expected_user install_script render_templates repo_clones; do
  ansible-playbook -i localhost, -c local "tests/$t.yml"
done
```

### 取り込み前の確認

`main` を取得する利用側では、`main` の破損が全体に波及します。変更を `main` へ取り込む前に、利用側（`ansible_for_wsl`、`infra`）の
`make check-branch BRANCH=<作業ブランチ>` で、作業ブランチを取得した状態の `--check -D` を確認してください。

## OpenCode（LiteLLM 経由でローカル LLM を使う）

`ai` グループ（workstation）の中で、OpenCode を npm で固定版導入し、LiteLLM 向けの設定を `~/.config/opencode/` に配置します。
server プロファイル（`ai` が無効）では何もしません。`tasks/opencode.yml` が処理し、`ai.yml` から `develop_setting_opencode_enabled` が真のときだけ呼ばれます。

### 変数

| 変数 | 既定 | 説明 |
|---|---|---|
| `develop_setting_opencode_enabled` | `true` | OpenCode の導入と設定の on/off（真偽値。`ai` が無効なら無関係） |
| `develop_setting_opencode_package` / `develop_setting_opencode_version` | `opencode-ai` / `1.19.3` | npm のパッケージ名と固定版 |
| `develop_setting_opencode_config_dir` | `~/.config/opencode` | 設定ディレクトリ（`0700`） |
| `develop_setting_opencode_base_url` | 空 | LiteLLM の接続先 URL。空のまま有効化すると失敗します |
| `develop_setting_opencode_models` | 空リスト | `{ id, name, context, output }` の一覧。`id` は LiteLLM の `model_name`。空のまま有効化すると失敗します |
| `develop_setting_opencode_default_model` / `develop_setting_opencode_small_model` | 空 | 既定モデルと小型モデルの `id`。空なら `opencode.json` に出力しません |
| `develop_setting_opencode_api_key_env` | `LITELLM_API_KEY` | キーを読む環境変数名。`opencode.json` は `{env:名前}` で参照し、値は書きません |
| `develop_setting_opencode_api_key_src` | 空 | キーを書いた Vault 暗号化ファイルの絶対パス。空なら `litellm.env` を配置しません |

モデル一覧は、LiteLLM 側の設定（`infra/service/llm-proxy/config/config.yaml` の `model_name`）と一致させてください。

### キーの渡し方

専用キーは LiteLLM で発行し、利用側の Playbook が `develop_setting_opencode_api_key_src` に Vault 暗号化ファイルを渡します。
中身は `LITELLM_API_KEY=<発行したキー>` の 1 行です。role は中身を読まず、`template` が復号して `~/.config/opencode/litellm.env`（`0600`）に配置します
（`no_log` と `backup` つき）。`~/.bash_profile` が、このファイルがあるときだけ `set -a` / `. file` / `set +a` で環境変数に読み込みます。
平文のキーはコミットしないでください。

### 版の固定と更新

- `autoupdate` は `false` にし、`opencode upgrade` は実行しません。版は `develop_setting_opencode_version` だけで管理します。
- 更新するときは、公開から 7 日以上経った版を選び（`~/.npmrc` の `minimum-release-age=7` と同じ基準）、この変数を書き換えます。
- 設定ファイルの書式（`provider` / `models` / `{env:...}` など）は調査の要約に基づきます。導入時に公式仕様と照合してください（未確認）。

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

1. `pre-commit` を apt パッケージでインストール
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
Windows ターゲットでは `ansible.windows`（`win_file` / `win_get_url` 等）と
`community.windows`（`win_lineinfile`）のモジュールを使用します。  
`requirements.yml` に追加し、`ansible-galaxy collection install` でインストールしてください:

```yaml
collections:
  - name: community.general
  - name: ansible.windows    # Windows ターゲットを使う場合
  - name: community.windows  # Windows ターゲットを使う場合
```

```bash
ansible-galaxy collection install -r requirements.yml
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

### カスタマイズ可能な変数

| 変数名 | デフォルト値 | 説明 |
|---|---|---|
| `develop_setting_target_user` | SSHログインユーザー | 設定の適用先ユーザー（Ubuntu タスク冒頭で自動検出） |
| `develop_setting_target_home` | SSHログインユーザーのホーム | 設定の適用先ホームディレクトリ（同上） |
| `develop_setting_claude_config_dir` | `~/.claude` | Claude 設定ディレクトリ（Ubuntu のみ） |
| `develop_setting_git_ssh_command` | `ssh -o StrictHostKeyChecking=accept-new` | clone/pull 時の `GIT_SSH_COMMAND` |
| `develop_setting_windows_from_wsl_enabled` | `false` | WSLからWindowsホーム配下へ設定するモードを有効化 |
| `develop_setting_windows_from_wsl_mount_dir` | `/mnt/` | WSLでのWindowsマウント基点 |
| `develop_setting_windows_user_name` | `""` | 設定対象のWindowsユーザー名 |
| `develop_setting_windows_home_dir` | `/mnt/c/Users/{user}` | WSL経由設定時のWindowsホームパス |
| `develop_setting_windows_claude_config_dir` | `/mnt/c/Users/{user}/.claude` | WSL経由設定時のClaude設定パス |

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