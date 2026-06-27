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