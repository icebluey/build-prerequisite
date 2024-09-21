#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

_services=(
'snapd.socket'
'snapd.service'
'snapd.apparmor.service'
'snapd.autoimport.service'
'snapd.core-fixup.service'
'snapd.failure.service'
'snapd.recovery-chooser-trigger.service'
'snapd.seeded.service'
'snapd.snap-repair.service'
'snapd.snap-repair.timer'
'snapd.system-shutdown.service'
)

for _service in ${_services[@]}; do
    systemctl stop ${_service} >/dev/null 2>&1
done
sleep 3
for _service in ${_services[@]}; do
    systemctl disable ${_service} >/dev/null 2>&1
done

sleep 2
apt autoremove --purge -y snapd
apt autoremove --purge -y lxd-installer
sleep 2
rm -vrf ~/snap
rm -vrf /snap
rm -vrf /var/snap
rm -vrf /var/lib/snapd
rm -vrf /var/cache/snapd
rm -vfr /tmp/snap.lxd
rm -vfr /tmp/snap-private-tmp

exit

