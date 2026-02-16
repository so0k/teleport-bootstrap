#!/bin/bash
set -e

# ref: https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh

install_script_version=1.25.0
# shellcheck disable=SC2034
support_email=support@datadoghq.com
variant=install_script_agent7

# DATADOG_RPM_KEY_CURRENT.public always contains key used to sign current
# repodata and newly released packages
# DATADOG_RPM_KEY_E09422B3.public expires in 2022
# DATADOG_RPM_KEY_FD4BF915.public expires in 2024
# DATADOG_RPM_KEY_B01082D3.public expires in 2028
RPM_GPG_KEYS=("DATADOG_RPM_KEY_CURRENT.public" "DATADOG_RPM_KEY_B01082D3.public" "DATADOG_RPM_KEY_FD4BF915.public" "DATADOG_RPM_KEY_E09422B3.public")

echo -e "\033[34m\n* Datadog Agent 7 install script v${install_script_version}\n\033[0m"

repository_url="datadoghq.com"
keys_url="keys.datadoghq.com"
yum_url="yum.${repository_url}"
agent_flavor="datadog-agent"
etcdir="/etc/datadog-agent"
config_file="${etcdir}/datadog.yaml"
confd_folder="${etcdir}/conf.d/"
agent_major_version=7
agent_dist_channel=stable
yum_version_path="${agent_dist_channel}/${agent_major_version}"

# Because of https://bugzilla.redhat.com/show_bug.cgi?id=1792506, we disable
# repo_gpgcheck on RHEL/CentOS 8.1
if grep -q "8\.1\(\b\|\.\)" /etc/redhat-release 2>/dev/null; then
  rpm_repo_gpgcheck=0
else
  rpm_repo_gpgcheck=1
fi

echo -e "\033[34m\n* Installing YUM sources for Datadog\n\033[0m"

gpgkeys=''
separator='\n       '
for key_path in "${RPM_GPG_KEYS[@]}"; do
  gpgkeys="${gpgkeys:+"${gpgkeys}${separator}"}https://${keys_url}/${key_path}"
done

UNAME_M=$(uname -m)
if [[ "${UNAME_M}" == "i686" ]] || [[ "${UNAME_M}" == "i386" ]] || [[ "${UNAME_M}" == "x86" ]]; then
  ARCHI="i386"
elif [[ "${UNAME_M}" == "aarch64" ]]; then
  ARCHI="aarch64"
else
  ARCHI="x86_64"
fi

sh -c "echo -e '[datadog]\nname = Datadog, Inc.\nbaseurl = https://${yum_url}/${yum_version_path}/${ARCHI}/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=${rpm_repo_gpgcheck}\npriority=1\ngpgkey=${gpgkeys}' > /etc/yum.repos.d/datadog.repo"

yum -y clean metadata

dnf_flag=""
if [[ -f "/usr/bin/dnf" ]] && { [[ ! -f "/usr/bin/yum" ]] || [[ -L "/usr/bin/yum" ]]; }; then
  dnf_flag="--best"
fi
echo -e "  \033[33mInstalling package(s): ${agent_flavor}\n\033[0m"
# shellcheck disable=SC2248,SC2250,2312
yum -y --disablerepo='*' --enablerepo='datadog' install $dnf_flag "${agent_flavor}" 2> >(tee /tmp/ddog_install_error_msg >&2) || yum -y install $dnf_flag "${agent_flavor}" 2> >(tee /tmp/ddog_install_error_msg >&2)

# print error summary if any
grep "Error Summary" -A3 /tmp/ddog_install_error_msg || true

# ensure DataDog Agent gets journal.d logs
# https://docs.datadoghq.com/integrations/journald/?tab=host
usermod -a -G systemd-journal dd-agent
mv /tmp/build-assets/datadog-agent/datadog.yaml "${config_file}"
cp -rv /tmp/build-assets/datadog-agent/conf.d/* "${confd_folder}"
rm -rf /tmp/build-assets/datadog-agent/conf.d/

printf "\033[31mThe %s won't start automatically at the end of the script, please API Key in datadog.yaml and start the %s manually.\n\033[0m\n" "${agent_flavor}" "${agent_flavor}"
chown dd-agent:dd-agent "${config_file}"
chown -R dd-agent:dd-agent "${confd_folder}"
chmod 640 "${config_file}"
# Creating or overriding the install information
install_info_content="---
install_method:
  tool: install_script
  tool_version: ${variant}
  installer_version: install_script-${install_script_version}
"
sh -c "echo '${install_info_content}' > ${etcdir}/install_info"

printf "\033[34m
* the newly installed version of the %s will not be started.
You will have to do it manually using the following command:

    systemctl start datadog-agent

\033[0m\n" "${agent_flavor}"
