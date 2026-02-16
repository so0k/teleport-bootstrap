#!/bin/bash -x
set -euo pipefail s

# shellcheck source=SCRIPTDIR/functions.sh
source /opt/teleport/scripts/functions.sh

_add_svc_user_al() {
  local -r name=$1
  groupadd "${name}"
  adduser --system --ingroup "${name}" "${name}"
  adduser "${name}" root
  chown "${name}:root" "/home/${name}/"
  chmod g=u "/home/${name}/"
  chmod g=u /etc/passwd
}

_main() {
  adduser --system --create-home --groups root --user-group "teleport"
  pushd /home/teleport || exit 1
  (
    cp /tmp/build-assets/teleport-agent/install-teleport-upstream.sh .
    # install teleport using upstream script
    ./install-teleport-upstream.sh "${TELEPORT_VERSION}"

    mv /tmp/build-assets/teleport-agent/init.sh /home/teleport/init.sh
    mv /tmp/build-assets/teleport-agent/confd/conf.d/* /etc/confd/conf.d/
    mv /tmp/build-assets/teleport-agent/confd/templates/* /etc/confd/templates/
    mv /tmp/build-assets/teleport-agent/teleport-watcher.{path,service} /home/teleport/
    systemd-analyze verify /home/teleport/teleport-watcher.*

    systemctl stop teleport
    # let confd trigger teleport through its watchers
    systemctl disable teleport
    chown -R teleport:root /home/teleport/
  )
}

_main "$@"
