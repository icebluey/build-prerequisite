#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

apt update -y -qqq
# build nettle for gnutls
apt install -y libgmp-dev
# build gnutls for chrony
apt install -y libp11-kit-dev libidn2-dev
# build chrony
apt install -y libseccomp-dev libcap-dev libedit-dev

LDFLAGS="-Wl,-z,relro -Wl,--as-needed -Wl,-z,now"
export LDFLAGS
_ORIG_LDFLAGS="$LDFLAGS"

CC=gcc
export CC
CXX=g++
export CXX

/sbin/ldconfig

set -e

_build_zstd() {

LDFLAGS=''
LDFLAGS="${_ORIG_LDFLAGS}"
export LDFLAGS

/sbin/ldconfig

set -e

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

#https://github.com/facebook/zstd.git
git clone "https://github.com/facebook/zstd.git"
sleep 1
cd zstd

#find ./ -iname Makefile | xargs -I "{}" sed 's@prefix.*?= /usr/local@prefix      ?= /usr@g' -i "{}"
#sed '/^libdir/s|)/lib$|)/lib/x86_64-linux-gnu|g' -i lib/Makefile
#sed 's@LIBDIR.*?= $(exec_prefix)/lib$@LIBDIR      ?= $(exec_prefix)/lib/x86_64-linux-gnu@'  -i lib/Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
sed '/^prefix/s|= .*|= /usr|g' -i Makefile
sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
#sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
#sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile

sleep 1
#make V=1 all prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
make -j2 V=1 lib prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
sleep 1
rm -fr /tmp/zstd
sleep 1
make install DESTDIR=/tmp/zstd
sleep 1
cd /tmp/zstd/
_zstd_ver="$(cat usr/lib/x86_64-linux-gnu/pkgconfig/libzstd.pc | grep '^Version: ' | awk '{print $NF}')"
sed 's|http:|https:|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/libzstd.pc
find usr/ -type f -iname '*.la' -delete
if [[ -d usr/share/man ]]; then
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
    find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
    sleep 2
    find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
    sleep 2
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
fi
find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so.*' -exec chmod 0755 '{}' \;
sleep 2
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/lib/x86_64-linux-gnu/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'

sleep 1
install -m 0755 -d usr/lib/x86_64-linux-gnu/chrony/private
sleep 1
cp -a usr/lib/x86_64-linux-gnu/*.so* usr/lib/x86_64-linux-gnu/chrony/private/

echo
sleep 2
tar -Jcvf /tmp/"zstd-${_zstd_ver}-1.el7.x86_64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"zstd-${_zstd_ver}-1.el7.x86_64.tar.xz" -C /

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/zstd
rm -fr /tmp/zstd*tar*
printf '\033[01;32m%s\033[m\n' '  build zstd done'
/sbin/ldconfig
echo
}

_build_brotli() {

LDFLAGS=''
LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'
export LDFLAGS

/sbin/ldconfig

set -e

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

git clone --recursive 'https://github.com/google/brotli.git' brotli
cd brotli
rm -fr .git
if [[ -f bootstrap ]]; then
    ./bootstrap
    rm -fr autom4te.cache
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --disable-static \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j2 all
    rm -fr /tmp/brotli
    make install DESTDIR=/tmp/brotli
else
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$ORIGIN' ; export LDFLAGS
    cmake \
    -S "." \
    -B "build" \
    -DCMAKE_BUILD_TYPE='Release' \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr \
    -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
    -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
    -DSYSCONF_INSTALL_DIR:PATH=/etc \
    -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
    -DLIB_SUFFIX=64 \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
    cmake --build "build"  --verbose
    rm -fr /tmp/brotli
    DESTDIR="/tmp/brotli" cmake --install "build"
fi
cd /tmp/brotli
sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
find usr/ -type f -iname '*.la' -delete
if [[ -d usr/share/man ]]; then
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
    find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
    sleep 2
    find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
    sleep 2
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
fi
find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so.*' -exec chmod 0755 '{}' \;
sleep 2
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/lib/x86_64-linux-gnu/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'

sleep 1
install -m 0755 -d usr/lib/x86_64-linux-gnu/chrony/private
sleep 1
cp -a usr/lib/x86_64-linux-gnu/*.so* usr/lib/x86_64-linux-gnu/chrony/private/

echo
sleep 2
tar -Jcvf /tmp/brotli-git-1.el7.x86_64.tar.xz *
echo
sleep 2
tar -xof /tmp/brotli-git-1.el7.x86_64.tar.xz -C /

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/brotli
rm -fr /tmp/brotli*tar*
printf '\033[01;32m%s\033[m\n' '  build brotli done'
/sbin/ldconfig
echo
}

_build_nettle () {

LDFLAGS=''
LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'
export LDFLAGS

/sbin/ldconfig

set -e

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_nettle_ver=$(wget -qO- 'https://ftp.gnu.org/gnu/nettle/' | grep -i 'a href="nettle.*\.tar' | sed 's/"/\n/g' | grep -i '^nettle-.*tar.gz$' | sed -e 's|nettle-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)
wget -c -t 0 -T 9 "https://ftp.gnu.org/gnu/nettle/nettle-${_nettle_ver}.tar.gz"
sleep 2
tar -xof nettle-*.tar*
sleep 2
rm -f nettle-*.tar*
cd nettle-*

./configure \
--build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu \
--includedir=/usr/include --sysconfdir=/etc \
--enable-shared --enable-static --enable-fat

make -j2 all
rm -fr /tmp/nettle
make install DESTDIR=/tmp/nettle

cd /tmp/nettle
if [[ -d usr/share/man ]]; then
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
    find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
    sleep 2
    find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
    sleep 2
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
fi
find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so.*' -exec chmod 0755 '{}' \;
sleep 2
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/lib/x86_64-linux-gnu/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc

sleep 1
mkdir -p usr/lib/x86_64-linux-gnu/chrony/private
sleep 1
cp -a usr/lib/x86_64-linux-gnu/*.so* usr/lib/x86_64-linux-gnu/chrony/private/

echo
sleep 2
tar -Jcvf /tmp/"nettle_${_nettle_ver}-1_amd64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"nettle_${_nettle_ver}-1_amd64.tar.xz" -C /

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/nettle
rm -fr /tmp/nettle*tar*
/sbin/ldconfig
sleep 2
echo
echo ' done'
echo
}

_build_gnutls () {

LDFLAGS=''
LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'
export LDFLAGS

/sbin/ldconfig

set -e

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_gnutls_ver="$(wget -qO- 'https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/' | grep -i 'a href="gnutls.*\.tar' | sed 's/"/\n/g' | grep -i '^gnutls-.*tar.xz$' | sed -e 's|gnutls-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
wget -c -t 0 -T 9 "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-${_gnutls_ver}.tar.xz"
sleep 2
tar -xof gnutls-*.tar*
sleep 2
rm -f gnutls-*.tar*
cd gnutls-*

./configure \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--enable-shared \
--enable-threads=posix \
--enable-sha1-support \
--enable-ssl3-support \
--enable-fips140-mode \
--disable-openssl-compatibility \
--with-included-unistring \
--with-included-libtasn1 \
--prefix=/usr \
--libdir=/usr/lib/x86_64-linux-gnu \
--includedir=/usr/include \
--sysconfdir=/etc

sleep 1
find ./ -type f -iname 'Makefile' | xargs -I "{}" sed 's| -Wl,-rpath -Wl,/usr/lib/x86_64-linux-gnu||g' -i "{}"
sleep 1
find ./ -type f -iname 'Makefile' | xargs -I "{}" sed 's| -R/usr/lib/x86_64-linux-gnu||g' -i "{}"
sleep 1
make -j2 all
rm -fr /tmp/gnutls
make install DESTDIR=/tmp/gnutls

cd /tmp/gnutls
if [[ -d usr/share/man ]]; then
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
    find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
    sleep 2
    find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
    sleep 2
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
fi
find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so.*' -exec chmod 0755 '{}' \;
sleep 2
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/lib/x86_64-linux-gnu/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
sleep 1
mkdir -p usr/lib/x86_64-linux-gnu/chrony/private
sleep 1
cp -a usr/lib/x86_64-linux-gnu/*.so* usr/lib/x86_64-linux-gnu/chrony/private/
echo
sleep 2
tar -Jcvf /tmp/"gnutls_${_gnutls_ver}-1_amd64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"gnutls_${_gnutls_ver}-1_amd64.tar.xz" -C /

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/gnutls
rm -fr /tmp/gnutls*tar*
/sbin/ldconfig
sleep 2
echo
echo ' done'
echo
}

_build_chrony () {

LDFLAGS=''
LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,/usr/lib/x86_64-linux-gnu/chrony/private'
export LDFLAGS

/sbin/ldconfig

set -e

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_chrony_ver=$(wget -qO- 'https://chrony-project.org/download.html' | grep 'chrony-[1-9].*\.tar' | sed 's|"|\n|g' | sed 's|chrony|\nchrony|g' | grep '^chrony-[1-9]' | sed -e 's|\.tar.*||g' -e 's|chrony-||g' | grep -ivE 'alpha|beta|rc[0-9]|pre' | sort -V | tail -n 1)
wget -c -t 0 -T 9 "https://chrony-project.org/releases/chrony-${_chrony_ver}.tar.gz"
sleep 2
tar -xof chrony-*.tar*
sleep 1
rm -f chrony-*.tar*
cd chrony-*

./configure \
--prefix=/usr \
--mandir=/usr/share/man \
--sysconfdir=/etc/chrony \
--chronyrundir=/run/chrony \
--docdir=/usr/share/doc \
--enable-scfilter \
--enable-ntp-signd \
--enable-debug \
--with-ntp-era=$(date -d '1970-01-01 00:00:00+00:00' +'%s') \
--with-hwclockfile=/etc/adjtime \
--with-pidfile=/run/chrony/chronyd.pid

make -j2 all
rm -fr /tmp/chrony
make install DESTDIR=/tmp/chrony
mkdir -p /tmp/chrony/etc/logrotate.d
cd examples
install -v -c -m 0644 chrony.conf.example2 /tmp/chrony/etc/chrony/chrony.conf
install -v -c -m 0640 chrony.keys.example /tmp/chrony/etc/chrony/chrony.keys
install -v -c -m 0644 chrony.logrotate /tmp/chrony/etc/logrotate.d/chrony
install -v -c -m 0644 chrony-wait.service /tmp/chrony/etc/chrony/chrony-wait.service
install -v -c -m 0644 chronyd.service /tmp/chrony/etc/chrony/chronyd.service

cd /tmp/chrony
rm -fr var/run
install -m 0755 -d etc/sysconfig
install -m 0755 -d usr/libexec/chrony
if [[ -d usr/share/man ]]; then
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
    find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
    sleep 2
    find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
    sleep 2
    find -L usr/share/man/ -type l -exec rm -f '{}' \;
fi
sleep 2
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'

sleep 1
mkdir -p usr/lib/x86_64-linux-gnu/chrony
sleep 1
cp -afr /usr/lib/x86_64-linux-gnu/chrony/private usr/lib/x86_64-linux-gnu/chrony/
rm -fr usr/lib/x86_64-linux-gnu/chrony/private/libgnutlsxx.*

sed -e 's|#\(driftfile\)|\1|' \
-e 's|#\(rtcsync\)|\1|' \
-e 's|#\(keyfile\)|\1|' \
-e 's|#\(leapsectz\)|\1|' \
-e 's|#\(logdir\)|\1|' \
-e 's|#\(authselectmode\)|\1|' \
-e 's|#\(ntsdumpdir\)|\1|' \
-i etc/chrony/chrony.conf

sed 's|/etc/chrony\.|/etc/chrony/chrony\.|g' -i etc/chrony/chrony.conf
sed 's/^pool /#pool /g' -i etc/chrony/chrony.conf
sed 's/^server/#server/g' -i etc/chrony/chrony.conf
sed 's/^allow /#allow /g' -i etc/chrony/chrony.conf
sed '5i# Use public NTS servers' -i etc/chrony/chrony.conf
sed '6iserver time.cloudflare.com iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '7iserver gbg1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '8iserver gbg2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '9iserver lul1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '10iserver lul2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '11iserver mmo1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '12iserver mmo2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '13iserver sth1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '14iserver sth2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '15iserver svl1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '16iserver svl2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts' -i etc/chrony/chrony.conf
sed '17i#server time1.google.com iburst minpoll 4 maxpoll 5' -i etc/chrony/chrony.conf
sed '18i#server time2.google.com iburst minpoll 4 maxpoll 5' -i etc/chrony/chrony.conf
sed '19i#server time3.google.com iburst minpoll 4 maxpoll 5' -i etc/chrony/chrony.conf
sed '20i#server time4.google.com iburst minpoll 4 maxpoll 5\n' -i etc/chrony/chrony.conf

echo 'ntsrefresh 300' >> etc/chrony/chrony.conf
echo 'refresh 300' >> etc/chrony/chrony.conf

sed 's|^ProcSubset|#ProcSubset|g' -i etc/chrony/chronyd.service
sed 's|^ProtectProc|#ProtectProc|g' -i etc/chrony/chronyd.service
sed '/^After=/aAfter=dnscrypt-proxy.service network-online.target' -i etc/chrony/chronyd.service
sed '/^ExecStart=/iExecStartPre=/usr/libexec/chrony/resolve-ntp-servers.sh' -i etc/chrony/chronyd.service

mkdir -p usr/lib/systemd/ntp-units.d
echo 'chronyd.service' > usr/lib/systemd/ntp-units.d/50-chronyd.list
echo 'chronyd.service' > usr/lib/systemd/ntp-units.d/50-chrony.list
sleep 1
chmod 0644 usr/lib/systemd/ntp-units.d/50-chrony*list

echo '# Command-line options for chronyd
OPTIONS=""' > etc/sysconfig/chronyd
sleep 1
chmod 0644 etc/sysconfig/chronyd

echo '#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='\''UTC'\''; export TZ

_ntpservers=(
'\''time.cloudflare.com'\''
'\''nts.ntp.se'\''
'\''nts.sth1.ntp.se'\''
'\''nts.sth2.ntp.se'\''
)
if [[ -f /usr/bin/dig ]]; then
    sleep 1
    for server in "${_ntpservers[@]}"; do
        /usr/bin/dig \
        +timeout=1 +tries=1 \
        "${server}" AAAA \
        >/dev/null 2>&1 & 
    done
    sleep 2
    for server in "${_ntpservers[@]}"; do
        /usr/bin/dig \
        +timeout=1 +tries=1 \
        "${server}" A \
        >/dev/null 2>&1 & 
    done
    sleep 2
fi
_ntpservers='\'''\''
exit 0
' > usr/libexec/chrony/resolve-ntp-servers.sh
sleep 1
chmod 0755 usr/libexec/chrony/resolve-ntp-servers.sh

echo '
cd "$(dirname "$0")"
/bin/systemctl stop chronyd >/dev/null 2>&1 || : 
/bin/systemctl stop chrony >/dev/null 2>&1 || : 
/bin/systemctl disable chronyd >/dev/null 2>&1 || : 
/bin/systemctl disable chrony >/dev/null 2>&1 || : 
rm -fr /lib/systemd/system/chrony.service
rm -fr /lib/systemd/system/chronyd.service
rm -fr /lib/systemd/system/chrony-wait.service
rm -fr /run/chrony
rm -f /etc/init.d/chrony
rm -fr /var/lib/chrony/*
/bin/systemctl daemon-reload >/dev/null 2>&1 || : 
sleep 1
install -v -c -m 0644 chronyd.service /lib/systemd/system/
install -v -c -m 0644 chrony-wait.service /lib/systemd/system/
ln -svf chronyd.service /lib/systemd/system/chrony.service
mkdir -p /var/log/chrony
mkdir -p /var/lib/chrony
touch /var/lib/chrony/{drift,rtc}
/bin/systemctl daemon-reload >/dev/null 2>&1 || : 
' > etc/chrony/.install.txt

chown -R root:root ./
echo
sleep 2
tar -Jcvf /tmp/"chrony_${_chrony_ver}-1_amd64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"chrony_${_chrony_ver}-1_amd64.tar.xz" -C /
/sbin/ldconfig
rm -fr /tmp/chrony

cd /tmp
rm -fr "${_tmp_dir}"
/sbin/ldconfig
sleep 2
echo
echo ' done'
echo

}

cd /tmp
rm -fr /usr/lib/x86_64-linux-gnu/chrony
_build_zstd
_build_brotli
_build_nettle
_build_gnutls
_build_chrony

rm -f /tmp/nettle*.tar*
rm -f /tmp/gnutls*.tar*

/sbin/ldconfig
sleep 2
echo
echo ' build chrony done'
echo ' build chrony done' >> /tmp/.done.txt
echo
exit

