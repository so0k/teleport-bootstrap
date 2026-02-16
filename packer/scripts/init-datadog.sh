#!/bin/bash

set -euox pipefail

# shellcheck source=SCRIPTDIR/functions.sh
source /opt/teleport/scripts/functions.sh

_init() {
  local -r api_key_arn=$1
  local -r host_tags=$2
  etcdir="/etc/datadog-agent"
  config_file="$etcdir/datadog.yaml"

  printf "\033[34m\n* Adding your API key to the DataDog Agent configuration: %s\n\033[0m\n" "${config_file}"

  apikey=$(_get_secrets "${api_key_arn}")
  sh -c "sed -i 's/api_key:.*/api_key: ${apikey}/' ${config_file}"
  # shellcheck disable=SC2001
  formatted_host_tags="['""$(echo "${host_tags}" | sed "s/,/','/g")""']" # format `env:prod,foo:bar` to yaml-compliant `['env:prod','foo:bar']`
  sh -c "sed -i \"s/# tags:.*/tags: ""${formatted_host_tags}""/\" ${config_file}"

  systemctl start datadog-agent
}

_show_help() {
  cat <<-EOF
	Usage: ./init [-hd]
	Initialize datadog agent

		-h, -help,          --help         Display help
		-k, -api-key-arn,   --api-key-arn  ARN to AWS Secret for DataDog Api Key
		-t, -host-tags,     --host-tags    Host tags in env:prod,foo:bar format
	EOF
}

_main() {
  local api_key_arn host_tags
  # ref: https://stackoverflow.com/a/52674277
  options=$(getopt -o hk:t: -l help,api-key-arn:,host-tags: -a -- "$@")
  eval set -- "$options"
  unset options
  while true; do
    case $1 in
      '-h' | '--help')
        _show_help
        exit 0
        ;;
      '-k' | '--api-key-arn')
        shift
        api_key_arn=$1
        ;;
      '-t' | '--host-tags')
        shift
        host_tags=$1
        ;;
      '--')
        shift
        break
        ;;
    esac
    shift
  done

  _init "${api_key_arn}" "${host_tags}"
}

_main "$@"
