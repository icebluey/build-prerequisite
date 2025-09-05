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

_private_dir='usr/lib/x86_64-linux-gnu/chrony/private'

set -e

_strip_files() {
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
}

_build_libseccomp() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    wget -c -t 9 -T 9 "https://github.com/seccomp/libseccomp/releases/download/v2.5.5/libseccomp-2.5.5.tar.gz"
    tar -xof libseccomp-*.tar*
    sleep 1
    rm -f libseccomp-*.tar*
    cd libseccomp-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin --sbindir=/usr/sbin \
    --sysconfdir=/etc --datadir=/usr/share --includedir=/usr/include \
    --libdir=/usr/lib/x86_64-linux-gnu --libexecdir=/usr/libexec --localstatedir=/var \
    --sharedstatedir=/var/lib --mandir=/usr/share/man --infodir=/usr/share/info \
    --enable-shared --enable-static
    make -j$(nproc --all) all
    rm -fr /tmp/libseccomp
    make DESTDIR=/tmp/libseccomp install
    cd /tmp/libseccomp
    _strip_files
    install -m 0755 -d usr/lib/x86_64-linux-gnu/chrony/private
    cp -af usr/lib/x86_64-linux-gnu/*.so* usr/lib/x86_64-linux-gnu/chrony/private/
    rm -vf /usr/lib/x86_64-linux-gnu/libseccomp.a
    rm -vf /usr/lib/x86_64-linux-gnu/libseccomp.so.2.5.[1234]
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libseccomp
    /sbin/ldconfig
}

_build_libedit() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libedit_ver="$(wget -qO- 'https://www.thrysoee.dk/editline/' | grep libedit-[1-9].*\.tar | sed 's|"|\n|g' | grep '^libedit-[1-9]' | sed -e 's|\.tar.*||g' -e 's|libedit-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.thrysoee.dk/editline/libedit-${_libedit_ver}.tar.gz"
    tar -xof libedit-*.tar.*
    sleep 1
    rm -f libedit-*.tar*
    cd libedit-*
    sed -i "s/lncurses/ltinfo/" configure
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu \
    --host=x86_64-linux-gnu \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --includedir=/usr/include \
    --sysconfdir=/etc \
    --enable-shared --enable-static \
    --enable-widec
    sleep 1
    make -j$(nproc --all) all
    rm -fr /tmp/libedit
    make install DESTDIR=/tmp/libedit
    cd /tmp/libedit
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -f /usr/lib/x86_64-linux-gnu/libedit.*
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libedit
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone 'https://github.com/google/brotli.git' brotli
    cd brotli
    rm -fr .git
    if [[ -f bootstrap ]]; then
        ./bootstrap
        rm -fr autom4te.cache
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
        ./configure \
        --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
        --enable-shared --disable-static \
        --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
        make -j$(nproc --all) all
        rm -fr /tmp/brotli
        make install DESTDIR=/tmp/brotli
    else
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$ORIGIN'; export LDFLAGS
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
        cmake --build "build" --parallel $(nproc --all) --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_zstd() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive "https://github.com/facebook/zstd.git"
    cd zstd
    rm -fr .git
    sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
    sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i lib/Makefile
    sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    #sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$OOORIGIN'; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C lib lib-mt
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C programs
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C contrib/pzstd
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd
    install -v -c -m 0755 contrib/pzstd/pzstd /tmp/zstd/usr/bin/
    cd /tmp/zstd
    ln -svf zstd.1 usr/share/man/man1/pzstd.1
    _strip_files
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}

_build_nettle() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _nettle_ver=$(wget -qO- 'https://ftp.gnu.org/gnu/nettle/' | grep -i 'a href="nettle.*\.tar' | sed 's/"/\n/g' | grep -i '^nettle-.*tar.gz$' | sed -e 's|nettle-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)
    wget -c -t 0 -T 9 "https://ftp.gnu.org/gnu/nettle/nettle-${_nettle_ver}.tar.gz"
    tar -xof nettle-*.tar*
    sleep 1
    rm -f nettle-*.tar*
    cd nettle-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu \
    --includedir=/usr/include --sysconfdir=/etc \
    --enable-shared --enable-static --enable-fat
    make -j$(nproc --all) all
    rm -fr /tmp/nettle
    make install DESTDIR=/tmp/nettle
    cd /tmp/nettle
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nettle
    /sbin/ldconfig
}

_build_gnutls() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _gnutls_ver="$(wget -qO- 'https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/' | grep -i 'a href="gnutls.*\.tar' | sed 's/"/\n/g' | grep -i '^gnutls-.*tar.xz$' | sed -e 's|gnutls-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 0 -T 9 "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-${_gnutls_ver}.tar.xz"
    tar -xof gnutls-*.tar*
    sleep 1
    rm -f gnutls-*.tar*
    cd gnutls-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
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
    find ./ -type f -iname 'Makefile' | xargs -I "{}" sed 's| -Wl,-rpath -Wl,/usr/lib/x86_64-linux-gnu||g' -i "{}"
    find ./ -type f -iname 'Makefile' | xargs -I "{}" sed 's| -R/usr/lib/x86_64-linux-gnu||g' -i "{}"
    make -j$(nproc --all) all
    rm -fr /tmp/gnutls
    make install DESTDIR=/tmp/gnutls
    cd /tmp/gnutls
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/gnutls
    /sbin/ldconfig
}

_build_chrony () {

LDFLAGS=''
LDFLAGS="${_ORIG_LDFLAGS}"
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

make -j$(nproc --all) all
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
-e 's|#\(ntsdumpdir\)|\1|' \
-i etc/chrony/chrony.conf

# -e 's|#\(authselectmode\)|\1|' \

sed 's|/etc/chrony\.|/etc/chrony/chrony\.|g' -i etc/chrony/chrony.conf
sed 's/^pool /#pool /g' -i etc/chrony/chrony.conf
sed 's/^server/#server/g' -i etc/chrony/chrony.conf
sed 's/^allow /#allow /g' -i etc/chrony/chrony.conf

sed '/^#pool /a\
\n\# Cloudflare NTS servers\
server time.cloudflare.com iburst minpoll 4 maxpoll 5 nts\
\n\# Netnod NTS servers\
server gbg1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server gbg2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server lul1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server lul2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server mmo1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server mmo2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server sth1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server sth2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server svl1.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
server svl2.nts.netnod.se iburst minpoll 4 maxpoll 5 nts\
\n\# Google NTP servers\
server time1.google.com iburst minpoll 4 maxpoll 5\
server time2.google.com iburst minpoll 4 maxpoll 5\
server time3.google.com iburst minpoll 4 maxpoll 5\
server time4.google.com iburst minpoll 4 maxpoll 5\
\n\# Apple NTP servers\
server sgsin3-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server sgsin3-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server brsao4-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server brsao4-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server hkhkg1-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server hkhkg1-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server hkhkg1-ntp-003.aaplimg.com iburst minpoll 4 maxpoll 5\
server ussjc2-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server ussjc2-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server uslax1-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server uslax1-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server usnyc3-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server usnyc3-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server usnyc3-ntp-003.aaplimg.com iburst minpoll 4 maxpoll 5\
server ausyd2-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server ausyd2-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server usqas2-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server usqas2-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server frcch1-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server frcch1-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server uklon5-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server uklon5-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server uklon5-ntp-003.aaplimg.com iburst minpoll 4 maxpoll 5\
server usmia1-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server usmia1-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server usatl4-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server usatl4-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server nlams2-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server nlams2-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server jptyo5-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server jptyo5-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server jptyo5-ntp-003.aaplimg.com iburst minpoll 4 maxpoll 5\
server usscz2-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server usscz2-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server sesto4-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server sesto4-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server defra1-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server defra1-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server defra1-ntp-003.aaplimg.com iburst minpoll 4 maxpoll 5\
server usdal2-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server usdal2-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server uschi5-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server uschi5-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server twtpe2-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server twtpe2-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server krsel6-ntp-001.aaplimg.com iburst minpoll 4 maxpoll 5\
server krsel6-ntp-002.aaplimg.com iburst minpoll 4 maxpoll 5\
server time.apple.com iburst minpoll 4 maxpoll 5
' -i etc/chrony/chrony.conf

sed 's|^#hwtimestamp|hwtimestamp|g' -i etc/chrony/chrony.conf
sed 's|^authselectmode |#authselectmode |g' -i etc/chrony/chrony.conf

echo 'ntsrefresh 300' >> etc/chrony/chrony.conf
echo 'refresh 300' >> etc/chrony/chrony.conf

sed 's|^ProcSubset|#ProcSubset|g' -i etc/chrony/chronyd.service
sed 's|^ProtectProc|#ProtectProc|g' -i etc/chrony/chronyd.service
sed '/^After=/aAfter=dnscrypt-proxy.service network-online.target' -i etc/chrony/chronyd.service
sed '/^ExecStart=/iExecStartPre=/usr/libexec/chrony/resolve-ntp-servers.sh' -i etc/chrony/chronyd.service
sed 's|^Type=.*|Type=forking|g' -i etc/chrony/chronyd.service
sed '/ExecStart=/s| -n||g' -i etc/chrony/chronyd.service

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

patchelf --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/chrony/private' usr/sbin/chronyd
patchelf --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/chrony/private' usr/bin/chronyc

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

_build_libseccomp
_build_libedit
_build_brotli
_build_zstd
_build_nettle
_build_gnutls
_build_chrony

rm -f /tmp/nettle*.tar*
rm -f /tmp/gnutls*.tar*

/sbin/ldconfig
sleep 2
echo
echo ' build chrony done'
echo
exit
