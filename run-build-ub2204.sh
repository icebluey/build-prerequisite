#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
sleep 5
docker run --cpus="2.0" --rm --name ub2204 -itd ubuntu:22.04 bash
sleep 2
docker exec ub2204 apt update -y
#docker exec ub2204 apt upgrade -fy
docker exec ub2204 apt install -y bash vim wget ca-certificates curl
docker exec ub2204 /bin/ln -svf bash /bin/sh
docker exec ub2204 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp ub2204 ub2204:/home/
docker exec ub2204 /bin/bash /home/ub2204/scripts/pre-install.txt
docker exec ub2204 /bin/bash /home/ub2204/scripts/.build-all.sh
rm -fr /home/.tmp
mkdir /home/.tmp
docker cp ub2204:/tmp/bintar /home/.tmp/
cd /home/.tmp
_dateutc=$(date -u +%Y-%m-%d-%H%M)
tar -cvf bintar-ub2204-"v${_dateutc}".tar bintar-ub2204-"v${_dateutc}"
sleep 2
sha256sum bintar-ub2204-"v${_dateutc}".tar > bintar-ub2204-"v${_dateutc}".tar.sha256
exit
