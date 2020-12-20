# cjvirtucio87's Ansible Playbooks

Playbooks for spinning up infrastructure for your machine. Currently supports `osx` and `ubuntu`.

## Configuration

You'll need the password to the vault file located in `/etc/ansible/vault.pass`.

## Usage

Run this command:

```bash
sudo ansible-playbook -e "managed_user=$(whoami)" <platform>_localhost.yml
```
