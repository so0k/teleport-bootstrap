#!/bin/bash -x
set -euo pipefail s

ARCH="arm64"

# shellcheck source=SCRIPTDIR/functions.sh
source /opt/teleport/scripts/functions.sh

_main() {
  adduser --system --create-home --groups root --user-group "confd"
  pushd /home/confd || exit 1
  (
    # https://github.com/abtreece/confd/releases
    _install_github_release \
      "abtreece/confd" \
      "${CONFD_VERSION}" \
      "confd" \
      "confd-${CONFD_VERSION}-linux-${ARCH}.tar.gz" \
      true

    mkdir -p /etc/confd/{conf.d,templates}

    # mv confd.service, confd.toml.tpl, init.sh to ~confd
    mv /tmp/build-assets/confd/* /home/confd/
    chown -R confd:root /home/confd/
  )
}

_main "$@"
