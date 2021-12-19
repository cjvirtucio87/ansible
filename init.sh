#!/bin/bash

set -e

### initialization script for setting up a local dev environment
###
### Usage:
###   <Options> init.sh <Arguments>
###
### Options:
###   ANSIBLE_FLAGS: additional flags to pass to ansible in the play stage
###   SKIP_REBOOT: skip reboot at the end
###   STAGES: space separated list of stages to run (default: apt python play)

ROOT_DIR="$(dirname "$(readlink --canonicalize "$0")")"
readonly ROOT_DIR
readonly ANSIBLE_VENV_DIR="${ROOT_DIR}/.ansible-venv"
readonly STAGES="${STAGES:-apt python galaxy_install play}"

function _apt {
  sudo apt-get update -y
  sudo apt-get install -y python3 python3-pip python3-venv lsb-core
}

function _galaxy_install {
  # shellcheck disable=SC1090,SC1091
  . "${ANSIBLE_VENV_DIR}/bin/activate"
  if ! ansible-galaxy install -r "${ROOT_DIR}/requirements.yml"; then
    >&2 echo failed to install galaxy requirements
    deactivate
    return 1
  fi

  deactivate
}

function _run_play {
  local play_args=(
    --ask-become-pass
    --extra-vars "managed_user=$(whoami)"
  )

  if [[ -v ANSIBLE_FLAGS ]]; then
    local flags
    IFS=' ' read -ra flags <<<"${ANSIBLE_FLAGS}"
    play_args+=("${flags[@]}")
  fi

  local cmd=(
    ansible-playbook
    "${play_args[@]}"
    ./init.yml
  )

  >&2 echo "play cmd: ${cmd[*]}"
  "${cmd[@]}"
}

function _play {
  if ! [[ -d "${ANSIBLE_VENV_DIR}" ]]; then
    >&2 echo "no ansible-venv created; please run the python stage before running the play stage"
    return 1
  fi

  # shellcheck disable=SC1090,SC1091
  . "${ANSIBLE_VENV_DIR}/bin/activate"
  if ! _run_play; then
    >&2 echo "failed running playbook"
    deactivate
    return 1
  fi

  deactivate

  if [[ ! -v SKIP_REBOOT ]]; then
    >&2 echo "play complete; rebooting in 10 seconds..."
    sudo shutdown --reboot "$(date --date 'now + 10 seconds' +%H:%M)"
  fi
}

function _pip {
  python -m pip install pip --upgrade
  python -m pip install wheel setuptools
  python -m pip install --requirement "${ROOT_DIR}/requirements.txt"
}

function _python {
  if [[ ! -d "${ANSIBLE_VENV_DIR}" ]]; then
    python3 -m venv "${ANSIBLE_VENV_DIR}"
    # shellcheck disable=SC1090,SC1091
    . "${ANSIBLE_VENV_DIR}/bin/activate"
    if ! _pip; then
      >&2 echo "failed pip install during python stage"
      deactivate
      return 1
    fi

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
      galaxy_install)
        _galaxy_install
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
