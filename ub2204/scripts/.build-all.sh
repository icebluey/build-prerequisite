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

apt update -y
if [[ -f /usr/local/sbin/unminimize ]]; then yes | /usr/local/sbin/unminimize; fi
bash pre-install.txt

bash build-dnscrypt-proxy.sh
mv -f /tmp/dnscrypt-proxy*.tar.xz* /tmp/.tar.tmp/

bash build-compress.sh
mv -f /tmp/*_amd64.tar.xz* /tmp/.tar.tmp/

bash build-gpg.sh
mkdir /tmp/.tar.tmp/gpg-bundle
mv -f /tmp/*_amd64.tar.xz* /tmp/.tar.tmp/gpg-bundle/

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

cd gpg-bundle
rm -f sha256sums.txt
rm -f *.sha256
sha256sum *.tar.xz > sha256sums.txt
echo '
gpgconf --kill all
sleep 1
pkill gpg-agent
rm -fr /etc/gnupg /usr/lib/x86_64-linux-gnu/gnupg/private /usr/lib/gnupg
sleep 1
/bin/ls -1 *.tar.xz | xargs -I '\''{}'\'' tar -xof '\''{}'\'' -C /
sleep 1
/sbin/ldconfig
bash /etc/gnupg/.install.txt
' > .install-gpg-bundle.txt
echo '
apt install -y libc6 libbz2-1.0 libldap-2.5-0 libreadline8 libusb-1.0-0 libglib2.0-0 libncursesw6 libsecret-1-0 libtinfo6 tar xz-utils
' > .dependencies.txt
cd ..

echo '
/bin/ls -1 *.tar.xz | xargs -I '\''{}'\'' tar -xof '\''{}'\'' -C /
sleep 1
/sbin/ldconfig
exit


#
systemctl disable ssh.service || : 
systemctl disable sshd.service || : 
systemctl disable ssh.socket || : 
systemctl disable sshd-keygen.service || : 
systemctl disable ssh-agent.service || : 
systemctl stop ssh.service || : 
systemctl stop sshd.service || : 
systemctl stop ssh.socket || : 
systemctl stop sshd-keygen.service || : 
systemctl stop ssh-agent.service || : 
systemctl stop chrony.service || : 
systemctl disable chrony.service || : 
systemctl stop chronyd.service || : 
systemctl disable chronyd.service || : 
systemctl stop dnscrypt-proxy.service || : 
systemctl disable dnscrypt-proxy.service || : 
sleep 1
rm -fr /etc/dnscrypt-proxy
rm -fr /etc/chrony /usr/lib/x86_64-linux-gnu/chrony/private /var/lib/chrony
rm -fr /etc/ssh /usr/lib/x86_64-linux-gnu/openssh/private /usr/lib/openssh


#
bash /etc/ssh/.install.txt
bash /etc/dnscrypt-proxy/.install.txt
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
systemctl start chronyd.service


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
