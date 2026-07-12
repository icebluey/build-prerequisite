#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

## Disable auto upgrade
#[ -f /etc/apt/apt.conf.d/20auto-upgrades ] && sed 's/APT::Periodic::Update-Package-Lists "[0-9]";/APT::Periodic::Update-Package-Lists "0";/g' -i /etc/apt/apt.conf.d/20auto-upgrades
#[ -f /etc/apt/apt.conf.d/20auto-upgrades ] && sed 's/APT::Periodic::Unattended-Upgrade "[0-9].*/APT::Periodic::Unattended-Upgrade "0";/g' -i /etc/apt/apt.conf.d/20auto-upgrades

apt-get clean
apt-get autoclean
apt clean
apt autoclean

rm -fr /var/cache/apt/archives
rm -fr /var/lib/apt/lists
rm -fr /var/lib/apt/mirrors
sleep 1
mkdir -p /var/cache/apt/archives/partial
mkdir -p /var/lib/apt/lists/partial
mkdir -p /var/lib/apt/mirrors/partial
rm -fr  /etc/apt/sources.list.d/*.save
exit
