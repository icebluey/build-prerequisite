#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

apt autoremove --purge -y needrestart
apt autoremove --purge -y ubuntu-pro-client ubuntu-pro-client-l10n

snap stop amazon-ssm-agent
sleep 1
snap disable amazon-ssm-agent
sleep 1
snap remove amazon-ssm-agent
sleep 1
rm -fr /snap/amazon-ssm-agent
rm -vfr ~/snap
rm -vfr /home/ubuntu/snap
apt autoremove --purge -y ec2-hibinit-agent ec2-instance-connect hibagent

echo
snap list --all
echo

systemctl stop multipath-tools
systemctl stop multipathd.socket
systemctl disable multipath-tools
systemctl disable multipathd.socket
apt autoremove --purge -y multipath-tools

exit
