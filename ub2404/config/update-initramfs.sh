#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

/sbin/ldconfig

#find /lib/modules/"$(ls -1 /lib/modules/ | sort -V | tail -n 1)"/ -iname "*.ko" -exec /usr/bin/xz -f -z -7 "{}" \;

sleep 2
rm -vf /lib/modules/"$(ls -1 /lib/modules/ | sort -V | tail -n 1)"/modules.dep
rm -vf /lib/modules/"$(ls -1 /lib/modules/ | sort -V | tail -n 1)"/modules.dep.bin
sleep 2
depmod -a "$(ls -1 /lib/modules/ | sort -V | tail -n 1)"
sleep 2
rm -vf /boot/initrd.img-"$(ls -1 /lib/modules/ | sort -V | tail -n 1)"
echo
sleep 2
update-initramfs -c -k "$(ls -1 /lib/modules/ | sort -V | tail -n 1)"

echo
echo ' done '
exit
