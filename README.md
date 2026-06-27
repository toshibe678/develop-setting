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
```

## 使い方

`requirements.yml` 例:

```yaml
roles:
  - name: develop_settiong
    src: https://github.com/toshibe678/develop-settiong.git
```

Playbook 例:

```yaml
- hosts: all
  gather_facts: true
  roles:
    - role: develop_settiong
```