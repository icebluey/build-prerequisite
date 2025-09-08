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

bash install-kernel.sh
bash pre-install.txt

bash build-dnscrypt-proxy-el9.sh
mv -f /tmp/dnscrypt-proxy*.tar.xz* /tmp/.tar.tmp/

bash build-compress-el9.sh
mv -f /tmp/*.el9.x86_64.tar.xz* /tmp/.tar.tmp/

bash build-gpg-bundle-el9.sh
mkdir /tmp/.tar.tmp/gpg-bundle
mv -f /tmp/*.el9.x86_64.tar.xz* /tmp/.tar.tmp/gpg-bundle/

bash build-openssh-el9.sh
mv -f /tmp/*.el9.x86_64.tar.xz* /tmp/.tar.tmp/

cp -pf pre-install.txt /tmp/.tar.tmp/requirements.txt
cp -pfr ../config /tmp/.tar.tmp/.config
cp -pf install-kernel.sh /tmp/.tar.tmp/.config/install-kernel.sh
chmod 0755 /tmp/.tar.tmp/.config/install-kernel.sh
sleep 2
mv -f /tmp/.tar.tmp /tmp/bintar
sleep 2
cd /tmp/bintar
rm -f sha256sums.txt
rm -f *.sha256
sha256sum *.tar.xz > sha256sums.txt

cd gpg-bundle
rm -f sha256sums.txt
rm -f *.sha256
sha256sum *.tar.xz > sha256sums.txt
echo '
gpgconf --kill all
sleep 1
pkill gpg-agent
rm -fr /etc/gnupg /usr/lib64/gnupg/private
sleep 1
/bin/ls -1 *.tar.xz | xargs -I '\''{}'\'' tar -xof '\''{}'\'' -C /
sleep 1
/sbin/ldconfig
bash /etc/gnupg/.install.txt
' > .install-gpg-bundle.txt
cd ..

echo '
/bin/ls -1 *.tar.xz | xargs -I '\''{}'\'' tar -xof '\''{}'\'' -C /
sleep 1
/sbin/ldconfig
exit


#
systemctl disable ssh.service >/dev/null 2>&1 || : 
systemctl disable sshd.service >/dev/null 2>&1 || : 
systemctl disable ssh.socket >/dev/null 2>&1 || : 
systemctl disable sshd-keygen.service >/dev/null 2>&1 || : 
systemctl disable ssh-agent.service >/dev/null 2>&1 || : 
systemctl stop ssh.service >/dev/null 2>&1 || : 
systemctl stop sshd.service >/dev/null 2>&1 || : 
systemctl stop ssh.socket >/dev/null 2>&1 || : 
systemctl stop sshd-keygen.service >/dev/null 2>&1 || : 
systemctl stop ssh-agent.service >/dev/null 2>&1 || : 
systemctl disable dnscrypt-proxy.service >/dev/null 2>&1 || : 
systemctl stop dnscrypt-proxy.service >/dev/null 2>&1 || : 
sleep 1
rm -fr /etc/dnscrypt-proxy
rm -fr /etc/ssh /usr/lib64/openssh/private /usr/libexec/openssh


#
bash /etc/ssh/.install.txt
bash /etc/dnscrypt-proxy/.install.txt
systemctl daemon-reload >/dev/null 2>&1 || : 
systemctl stop systemd-timesyncd >/dev/null 2>&1
systemctl disable systemd-timesyncd >/dev/null 2>&1
systemctl disable dnscrypt-proxy.service >/dev/null 2>&1 || : 
systemctl disable sshd.service >/dev/null 2>&1 || : 
systemctl disable ssh.service >/dev/null 2>&1 || : 
systemctl enable sshd.service || : 
systemctl enable dnscrypt-proxy.service || : 
systemctl start dnscrypt-proxy.service

' > .install.txt

cd /tmp
sleep 1
rm -fr /tmp/.tar.tmp

sleep 1
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
