systemctl stop systemd-resolved.service
systemctl stop systemd-timesyncd
systemctl stop unattended-upgrades
systemctl stop udisks2.service
systemctl disable systemd-resolved.service
systemctl disable systemd-timesyncd
systemctl disable unattended-upgrades
systemctl disable udisks2.service
systemctl stop systemd-resolved.service
rm -fr /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf 
echo
echo 'set hostname:'
echo "hostnamectl --static hostname 'xxx'"
echo

