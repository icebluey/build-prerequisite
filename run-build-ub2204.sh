#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
sleep 5
echo
cat /proc/cpuinfo
echo
if [ "$(cat /proc/cpuinfo | grep -i '^processor' | wc -l)" -gt 1 ]; then
    docker run --cpus="$(cat /proc/cpuinfo | grep -i '^processor' | wc -l).0" --rm --name ub2204 -itd ubuntu:22.04 bash
else
    docker run --rm --name ub2204 -itd ubuntu:22.04 bash
fi
sleep 2
docker exec ub2204 apt update -y
#docker exec ub2204 apt upgrade -fy
docker exec ub2204 apt install -y bash wget ca-certificates curl
docker exec ub2204 /bin/ln -svf bash /bin/sh
docker exec ub2204 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp ub2204 ub2204:/home/
docker exec ub2204 /bin/bash /home/ub2204/scripts/pre-install.txt
docker exec ub2204 /bin/bash /home/ub2204/scripts/.build-all.sh
mkdir -p /tmp/_output_assets
docker cp ub2204:/tmp/bintar /tmp/_output_assets/
cd /tmp/_output_assets
_dateutc=$(date -u +%Y-%m-%d)
mv -f bintar ub2204-"v${_dateutc}"
sleep 1
tar -cvf ub2204-"v${_dateutc}".tar ub2204-"v${_dateutc}"
sleep 1
sha256sum ub2204-"v${_dateutc}".tar > ub2204-"v${_dateutc}".tar.sha256
/bin/rm -fr ub2204-"v${_dateutc}"
exit

