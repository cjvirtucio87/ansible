#!/bin/bash

set -e

ROOT_DIR="$(dirname "$(readlink --canonicalize "$0")")"
readonly ROOT_DIR
readonly ANSIBLE_VENV_DIR="${HOME}/.ansible-venv"

function main {
  sudo apt-get update -y
  sudo apt-get install -y python3 python3-pip python3-venv lsb-core

  if [[ ! -d "${ANSIBLE_VENV_DIR}" ]]; then
    python3 -m venv "${ANSIBLE_VENV_DIR}"
    . "${ANSIBLE_VENV_DIR}/bin/activate"
    python -m pip install pip --upgrade
    python -m pip install wheel setuptools
    python -m pip install --requirement "${ROOT_DIR}/requirements.txt"
    deactivate
  fi

  . "${ANSIBLE_VENV_DIR}/bin/activate"

  ansible-playbook ./init.yml --extra-vars "managed_user=$(whoami)"
}

main
