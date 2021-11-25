#!/bin/bash

set -e

ROOT_DIR="$(dirname "$(readlink --canonicalize "$0")")"
readonly ROOT_DIR
readonly ANSIBLE_VENV_DIR="${HOME}/.ansible-venv"
readonly STAGES="${STAGES:-apt python play}"

function _apt {
  sudo apt-get update -y
  sudo apt-get install -y python3 python3-pip python3-venv lsb-core
}

function _play {
  if ! [[ -d "${ANSIBLE_VENV_DIR}" ]]; then
    >&2 echo "no ansible-venv created; please run the python stage before running the play stage"
    return 1
  fi

  # shellcheck disable=SC1090,SC1091
  . "${ANSIBLE_VENV_DIR}/bin/activate"

  local play_args=(
    --extra-vars "managed_user=$(whoami)"
  )

  if [[ -v ANSIBLE_FLAGS ]]; then
    local flags
    IFS=' ' read -ra flags <<<"${ANSIBLE_FLAGS}"
    play_args+=("${flags[@]}")
  fi

  ansible-playbook ./init.yml "${play_args[@]}"
}

function _python {
  if [[ ! -d "${ANSIBLE_VENV_DIR}" ]]; then
    python3 -m venv "${ANSIBLE_VENV_DIR}"
    . "${ANSIBLE_VENV_DIR}/bin/activate"
    python -m pip install pip --upgrade
    python -m pip install wheel setuptools
    python -m pip install --requirement "${ROOT_DIR}/requirements.txt"
    deactivate
  fi
}

function main {
  local stages
  IFS=' ' read -ra stages <<<"${STAGES}"

  for stage in "${stages[@]}"; do
    case "${stage}" in
      apt)
        _apt
        ;;
      play)
        _play
        ;;
      python)
        _python
        ;;
      *)
        >&2 echo "unsupported stage [${stage}]"
        return 1
    esac
  done
}

main
