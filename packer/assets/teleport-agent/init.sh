#!/bin/bash

set -euox pipefail

source /opt/teleport/scripts/functions.sh

_init() {
  cd /home/teleport || exit

  ln -s /home/teleport/teleport-watcher.{path,service} /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable teleport-watcher.{path,service}
  systemctl start teleport-watcher.path
}

_show_help() {
  cat <<-EOF
	Usage: ./init [-hd]
	Initialize teleport

		-h, -help,         --help          Display help
	EOF
}

_main() {
  # ref: https://stackoverflow.com/a/52674277
  options=$(getopt -o h -l help -a -n init.sh -- "$@")
  eval set -- "$options"
  unset options
  while true; do
    case "$1" in
      '-h' | '--help')
        _show_help
        exit 0
        ;;
      '--')
        shift
        break
        ;;
    esac
    shift
  done

  _init
}

_main "$@"
