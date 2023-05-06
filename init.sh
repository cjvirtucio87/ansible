#!/bin/bash

set -e

### initialization script for setting up a local dev environment
###
### Usage:
###   <Options> init.sh
###
### Options:
###   ANSIBLE_FLAGS: additional flags to pass to ansible in the play stage
###   ROLES: space-delimited list of roles to init (default: cjvdev)
###   STAGES: space separated list of stages to run (default: all)
###
### Examples:
###   Initialize the WSL role:
###     ROLES=cjvdev_wsl ./init.sh
###
###   Run only the playbook stage:
###     STAGES=play ./init.sh
###
###   Add verbosity and extra-vars:
###     ANSIBLE_FLAGS='-vvvvvv --extra-vars "foo=bar"' ./init.sh

ROOT_DIR="$(dirname "$(readlink --canonicalize "$0")")"
readonly ROOT_DIR
readonly ANSIBLE_VENV_DIR="${ROOT_DIR}/.ansible-venv"
readonly ROLES="${ROLES:-cjvdev}"
readonly STAGES="${STAGES:-all}"

function _apt {
  sudo apt-get update -y
  sudo apt-get install -y python3 python3-pip python3-venv lsb-core
}

function _contains {
  local val="$1"
  local arr=("${@:2}")

  for item in "${arr[@]}"; do
    if [[ "${val}" == "${item}" ]]; then
      return
    fi
  done

  return 1
}

function _is_chosen_stage {
  local stage="$1"
  local chosen_stages=("${@:2}")

  for chosen_stage in "${chosen_stages[@]}"; do
    if [[ "${chosen_stage}" == 'all' ]] || [[ "${stage}" == "${chosen_stage}" ]]; then
      return
    fi
  done

  return 1
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

function _transdebian_repo {
  local repo_cfg
  read -r -d '' repo_cfg <<EOF || :
deb https://arkane-systems.github.io/wsl-transdebian/apt/ $(lsb_release -cs) main
deb-src https://arkane-systems.github.io/wsl-transdebian/apt/ $(lsb_release -cs) main
EOF

  local repo_list=/etc/apt/sources.list.d/wsl-transdebian.list
  if [[ -f "${repo_list}" ]] && diff <(echo "${repo_cfg}") "${repo_list}"; then
    >&2 echo "transdebian repo already setup"
    return
  fi

  sudo curl \
    --location \
    --output /etc/apt/trusted.gpg.d/wsl-transdebian.gpg \
    https://arkane-systems.github.io/wsl-transdebian/apt/wsl-transdebian.gpg

  sudo chmod a+r /etc/apt/trusted.gpg.d/wsl-transdebian.gpg
  echo "${repo_cfg}" | sudo dd of="${repo_list}"
}

function _play {
  if ! [[ -d "${ANSIBLE_VENV_DIR}" ]]; then
    >&2 echo "no ansible-venv created; please run the python stage before running the play stage"
    return 1
  fi

  # intentionally quoting the init_roles json
  # shellcheck disable=SC2027
  local play_args=(
    --ask-become-pass
    --extra-vars "{\"init_roles\": [$(IFS=, echo -n "${ROLES[*]}")]}"
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

  # shellcheck disable=SC1090
  . "${ANSIBLE_VENV_DIR}/bin/activate"
  command -v ansible-playbook
  "${cmd[@]}"
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

function _help {
  local line
  while read -r line; do
    if [[ "${line}" =~ ^### ]]; then
      echo "${line}"
    fi
  done < "$(readlink -f "$0")" | less
}

function main {
  if [[ "$1" == help ]]; then
    _help
    return
  fi

  local chosen_stages
  IFS=' ' read -ra chosen_stages <<<"${STAGES}"

  local stages=(
    apt
    python
    galaxy_install
    play
  )

  for stage in "${stages[@]}"; do
    if _is_chosen_stage "${stage}" "${chosen_stages[@]}"; then
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
    fi
  done

  >&2 echo 'All set!'
}

main "$@"
