#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

cd "$(dirname "$0")"

_start_epoch="$(date -u +%s)"
starttime="$(echo ' Start Time:  '"$(date -ud @"${_start_epoch}")")"
echo " ${starttime}"

/sbin/ldconfig

rm -fr /tmp/*
rm -fr /tmp/.tar.tmp*
rm -fr /tmp/bintar*
rm -fr /tmp/.done.txt

mkdir /tmp/.tar.tmp

set -e

bash pre-install.txt

bash build-dnscrypt-proxy.sh
mv -f /tmp/dnscrypt-proxy*.tar.xz* /tmp/.tar.tmp/

bash build-compress.sh
mv -f /tmp/*_amd64.tar.xz* /tmp/.tar.tmp/

bash build-gpg.sh
mv -f /tmp/*_amd64.tar.xz* /tmp/.tar.tmp/

bash build-openssh.sh
mv -f /tmp/*_amd64.tar.xz* /tmp/.tar.tmp/

bash build-chrony.sh
mv -f /tmp/*_amd64.tar.xz* /tmp/.tar.tmp/

cp -pf pre-install.txt /tmp/.tar.tmp/requirements.txt
cp -pfr ../config /tmp/.tar.tmp/.config
sleep 2
mv -f /tmp/.tar.tmp /tmp/bintar
sleep 2
cd /tmp/bintar
rm -f sha256sums.txt
rm -f *.sha256
sha256sum *.tar.xz > sha256sums.txt

echo '
/bin/ls -1 *.tar.xz | xargs -I '\''{}'\'' tar -xof '\''{}'\'' -C /
sleep 2
/sbin/ldconfig
exit


#
gpgconf --kill all
sleep 1
pkill gpg-agent
systemctl disable ssh >/dev/null 2>&1 || : 
systemctl disable sshd >/dev/null 2>&1 || : 
systemctl disable ssh.socket >/dev/null 2>&1 || : 
systemctl disable sshd-keygen.service >/dev/null 2>&1 || : 
systemctl disable ssh-agent.service >/dev/null 2>&1 || : 
systemctl stop ssh >/dev/null 2>&1 || : 
systemctl stop sshd >/dev/null 2>&1 || : 
systemctl stop ssh.socket >/dev/null 2>&1 || : 
systemctl stop sshd-keygen.service >/dev/null 2>&1 || : 
systemctl stop ssh-agent.service >/dev/null 2>&1 || : 
systemctl stop chrony >/dev/null 2>&1 || : 
systemctl disable chrony >/dev/null 2>&1 || : 
systemctl stop dnscrypt-proxy.service || : 
systemctl stop sshd.service || : 
systemctl stop ssh.service || : 
systemctl stop chronyd.service || : 
systemctl stop chrony.service || : 
systemctl disable dnscrypt-proxy.service || : 
systemctl disable sshd.service || : 
systemctl disable ssh.service || : 
systemctl disable chronyd.service || : 
systemctl disable chrony.service || : 
sleep 1
rm -fr /etc/ssh /etc/dnscrypt-proxy /etc/gnupg /etc/chrony
rm -fr /usr/lib/x86_64-linux-gnu/chrony /var/lib/chrony


#
bash /etc/ssh/.install.txt
bash /etc/dnscrypt-proxy/.install.txt
bash /etc/gnupg/.install.txt
bash /etc/chrony/.install.txt
systemctl stop systemd-timesyncd >/dev/null 2>&1
systemctl disable systemd-timesyncd >/dev/null 2>&1
systemctl disable dnscrypt-proxy.service || : 
systemctl disable sshd.service || : 
systemctl disable ssh.service || : 
systemctl disable chronyd.service || : 
systemctl disable chrony.service || : 
systemctl enable dnscrypt-proxy.service || : 
systemctl enable sshd.service || : 
systemctl enable chronyd.service || : 
systemctl start dnscrypt-proxy.service
sleep 5 ; systemctl start chronyd.service


' > .install.txt

cd /tmp
sleep 1
rm -fr /tmp/.tar.tmp

echo
cat /tmp/.done.txt
echo
rm -f /tmp/.done.txt

sleep 2
_end_epoch="$(date -u +%s)"
finishtime="$(echo ' Finish Time:  '"$(date -ud @"${_end_epoch}")")"
_del_epoch=$((${_end_epoch} - ${_start_epoch}))
_elapsed_days=$((${_del_epoch} / 86400))
_del_mod_days=$((${_del_epoch} % 86400))
elapsedtime="$(echo 'Elapsed Time:  '"${_elapsed_days} days ""$(date -u -d @${_del_mod_days} +"%T")")"
echo
echo " ${starttime}"
echo "${finishtime}"
echo "${elapsedtime}"
echo
echo
echo ' all done'
echo
exit
