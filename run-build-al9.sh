#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
cd "$(dirname "$0")"
systemctl start docker
sleep 5
echo
lscpu
echo
cat /proc/cpuinfo
echo
if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --hostname 'x86-040.build.eng.bos.redhat.com' --rm --name al9 -itd almalinux:9 bash
else
    docker run --hostname 'x86-040.build.eng.bos.redhat.com' --rm --name al9 -itd almalinux:9 bash
fi
sleep 2
docker exec al9 yum clean all
docker exec al9 yum makecache
docker exec al9 yum install -y wget bash
docker exec al9 /bin/bash -c 'ln -svf bash /bin/sh'
docker exec al9 /bin/bash -c 'rm -fr /tmp/*'
docker cp al9 al9:/home/
docker exec al9 /bin/bash /home/al9/scripts/.build-all.sh
mkdir -p /tmp/_output_assets
docker cp al9:/tmp/bintar /tmp/_output_assets/
cd /tmp/_output_assets
_dateutc=$(date -u +%Y-%m-%d)
mv -f bintar al9-"v${_dateutc}"
sleep 1
tar -cvf al9-"v${_dateutc}".tar al9-"v${_dateutc}"
sleep 1
sha256sum al9-"v${_dateutc}".tar > al9-"v${_dateutc}".tar.sha256
/bin/rm -fr al9-"v${_dateutc}"
exit

