#!/bin/bash

_add_svc_user() {
  local -r name=$1
  addgroup "${name}"
  adduser --system --ingroup "${name}" "${name}"
  adduser "${name}" root
  chown "${name}":root /home/"${name}"/
  chmod g=u /home/"${name}"/
  chmod g=u /etc/passwd
}

_get_secrets() {
  local -r name=$1
  secrets=$(aws secretsmanager get-secret-value --secret-id "${name}" --query "SecretString" --output text)
  echo "${secrets}"
}

_install_github_release() {
  local -r repo=$1
  local -r version=$2
  local -r binary=$3
  local -r asset_name=$4
  local -r tgz=${5:-false}

  if [[ "${tgz}" == "true" ]]; then
    curl --no-progress-meter -Lo "${binary}.tgz" "https://github.com/${repo}/releases/download/${version}/${asset_name}"
    tar -xzf "${binary}.tgz" && rm -rf "${binary}.tgz"
  else
    curl --no-progress-meter -Lo "${binary}" "https://github.com/${repo}/releases/download/${version}/${asset_name}"
  fi
  chmod +x "${binary}"
  mv "${binary}" "/usr/local/bin/${binary}"
}
