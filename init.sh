#!/bin/bash

set -e

### Initialization script for the dev environment.
###
### Required environment variables:
###   MANAGED_USER
###     For specifying the user to be managed by this script, e.g. MANAGED_USER="$(whoami)".
###
### Optional environment variables:
###   ANSIBLE_DEFAULT_VAULT_PASS
###     The default ansible vault password file.
###   PLATFORM
###     The platform that this script is being executed on.
###   SKIP_DEPS
###     Skip installing dependencies for this script..
###   SKIP_TEMPLATES
###     Skip templating pre-playbook configuration.
###
### Examples:
###   SKIP_DEPS=1 ./init.sh (skip dependencies)
###   SKIP_TEMPLATES=1 ./init.sh (skip templates)
###   SKIP_DEPS=1 SKIP_TEMPLATES=1 ./init.sh (skip dependencies and templates)

ROOT_DIR="$(dirname "$(readlink --canonicalize "$0")")"

ANSIBLE_DEFAULT_VAULT_PASS="${ANSIBLE_DEFAULT_VAULT_PASS:-vault.pass}"
ANSIBLE_REPO='ppa:ansible/ansible}'
CLCONF_VERSION='2.0.13'
PLATFORM="${PLATFORM:-wsl_ubuntu}"
PYTHON_VER='3.6'

main() {
  if [ -z "${MANAGED_USER}" ]; then
    echo "must specify the MANAGED_USER environment variable"
    exit 1
  fi

  local clconf_dir='.clconf'
  local clconf_file="${clconf_dir}/${CLCONF_VERSION}"
  if [[ -z "${SKIP_DEPS}" ]]; then
    echo 'installing ansible and python'
    apt update
    apt install --yes 'software-properties-common'
    apt-add-repository --yes --update "${ANSIBLE_REPO}"
    apt-get install -y "python${PYTHON_VER}" 'ansible'
    apt-get clean
    echo 'done'

    echo 'installing pip'
    curl https://bootstrap.pypa.io/get-pip.py | "python${PYTHON_VER}"
    echo 'done'

    if [[ ! -f "${clconf_file}" ]]; then
      echo 'installing clconf'
      mkdir --parents "${clconf_dir}/bin"
      curl \
        --location \
        --output "${clconf_dir}/bin/clconf" \
        "https://github.com/pastdev/clconf/releases/download/v${CLCONF_VERSION}/clconf-linux"
      chmod --recursive 0755 "${clconf_dir}/bin"
      touch "${clconf_file}"
      echo 'done'
    fi
  fi

  if [ -z "${SKIP_TEMPLATES}" ]; then
    echo 'templating config with clconf'
    ANSIBLE_DEFAULT_VAULT_PASS="${ANSIBLE_DEFAULT_VAULT_PASS}" "${clconf_dir}/bin/clconf" \
      template \
        templates/ansible/ \
        /etc/ansible/
    echo 'done'
  fi

  cd "${ROOT_DIR}"

  local playbook="${PLATFORM}_localhost.yml"
  echo "running playbook, ${playbook}, with user, ${MANAGED_USER}"
  ansible-playbook -i dev.ini -e "managed_user=${MANAGED_USER}" "${playbook}"
}

main "$@"
