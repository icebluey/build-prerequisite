#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

# delete snap
snap remove --purge lxd
snap remove --purge $(snap list | awk 'NR > 1 && $1 !~ /lxd/ && $1 !~ /snapd/ {print $1}' | sort -V | uniq | paste -sd" ")
snap remove --purge lxd
snap remove --purge snapd
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
for _service in ${_services[@]}; do
    systemctl disable ${_service} >/dev/null 2>&1
done
systemctl disable snapd.service
systemctl disable snapd.socket
systemctl disable snapd.seeded.service
systemctl stop snapd.service
systemctl stop snapd.socket
systemctl stop snapd.seeded.service
apt autoremove --purge lxd-agent-loader snapd
/bin/rm -rf ~/snap
/bin/rm -rf /snap
/bin/rm -rf /var/snap
/bin/rm -rf /var/lib/snapd
/bin/rm -rf /var/cache/snapd
/bin/rm -fr /tmp/snap.lxd
/bin/rm -fr /tmp/snap-private-tmp
/bin/rm -fr /usr/lib/snapd

exit

