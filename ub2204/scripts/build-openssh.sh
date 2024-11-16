#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX

/sbin/ldconfig

_private_dir='usr/lib/x86_64-linux-gnu/openssh/private'

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

_build_zlib() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc --64
    make -j$(nproc) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.so*
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.a
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_brotli() {
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
        make -j$(nproc) all
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
        cmake --build "build" --parallel $(nproc --all) --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
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
    #sed '/^LIBDIR/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
    #sed '/^libdir/s|= .*|= /usr/lib/x86_64-linux-gnu|g' -i programs/Makefile
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$OOORIGIN' ; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C lib lib-mt
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"; export LDFLAGS
    make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C programs
    rm -fr /tmp/zstd
    make install DESTDIR=/tmp/zstd
    cd /tmp/zstd
    _strip_files
    find usr/lib/x86_64-linux-gnu/ -type f -iname '*.so*' | xargs -I '{}' chrpath -r '$ORIGIN' '{}'
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zstd
    /sbin/ldconfig
}

_build_openssl33() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #_openssl33_ver="$(wget -qO- 'https://www.openssl.org/source/' | grep 'openssl-3\.3\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.3\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    #wget -c -t 9 -T 9 "https://www.openssl.org/source/openssl-${_openssl33_ver}.tar.gz"
    _openssl33_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.3\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.3\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/openssl/openssl/releases/download/openssl-${_openssl33_ver}/openssl-${_openssl33_ver}.tar.gz"
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc) all
    rm -fr /tmp/openssl33
    make DESTDIR=/tmp/openssl33 install_sw
    cd /tmp/openssl33
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl33
    /sbin/ldconfig
}

_build_openssl34() {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl34_ver="$(wget -qO- 'https://openssl-library.org/source/index.html' | grep 'openssl-3\.4\.' | sed 's|"|\n|g' | sed 's|/|\n|g' | grep -i '^openssl-3\.4\..*\.tar\.gz$' | cut -d- -f2 | sed 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/openssl/openssl/releases/download/openssl-${_openssl34_ver}/openssl-${_openssl34_ver}.tar.gz"
    tar -xof openssl-*.tar*
    sleep 1
    rm -f openssl-*.tar*
    cd openssl-*
    # Only for debian/ubuntu
    sed '/define X509_CERT_FILE .*OPENSSLDIR "/s|"/cert.pem"|"/certs/ca-certificates.crt"|g' -i include/internal/cryptlib.h
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib/x86_64-linux-gnu \
    --openssldir=/etc/ssl \
    enable-zlib enable-zstd enable-brotli \
    enable-argon2 enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-ec enable-ecdh enable-ecdsa \
    enable-ec_nistp_64_gcc_128 \
    enable-poly1305 enable-ktls enable-quic \
    enable-md2 enable-rc5 \
    no-mdc2 no-ec2m \
    no-sm2 no-sm2-precomp no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make -j$(nproc) all
    rm -fr /tmp/openssl34
    make DESTDIR=/tmp/openssl34 install_sw
    cd /tmp/openssl34
    # Only for debian/ubuntu
    mkdir -p usr/include/x86_64-linux-gnu/openssl
    chmod 0755 usr/include/x86_64-linux-gnu/openssl
    install -c -m 0644 usr/include/openssl/opensslconf.h usr/include/x86_64-linux-gnu/openssl/
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl34
    /sbin/ldconfig
}

_install_fido2 () {
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libfido2_ver="$(wget -qO- 'https://developers.yubico.com/libfido2/Releases/' | grep -i 'a href="libfido2-.*\.tar' | sed 's|"|\n|g' | grep -iv '\.sig' | grep -i '^libfido2' | sed -e 's|libfido2-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -q -c -t 9 -T 9 "https://developers.yubico.com/libfido2/Releases/libfido2-${_libfido2_ver}.tar.gz"
    sleep 1
    tar -xof "libfido2-${_libfido2_ver}.tar.gz"
    sleep 1
    rm -f libfido*.tar*
    cd "libfido2-${_libfido2_ver}"
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$ORIGIN' ; export LDFLAGS
    cmake -S . -B build -G 'Unix Makefiles' -DCMAKE_BUILD_TYPE:STRING='Debug' \
    -DCMAKE_INSTALL_SO_NO_EXE=0 -DUSE_PCSC=ON \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib/x86_64-linux-gnu
    /usr/bin/cmake --build "build"  --verbose
    rm -fr /tmp/libfido2
    DESTDIR="/tmp/libfido2" /usr/bin/cmake --install "build"
    cd /tmp/libfido2
    sleep 1
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -f /usr/lib/x86_64-linux-gnu/libfido2.*
    rm -f /usr/include/fido.h
    rm -fr /usr/include/fido
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libfido2
    /sbin/ldconfig >/dev/null 2>&1
}

rm -fr /usr/lib/x86_64-linux-gnu/openssh/private
_build_zlib
_build_brotli
_build_zstd
_build_openssl33
#_build_openssl34
_install_fido2

LDFLAGS=''
#LDFLAGS="-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,/usr/local/openssl-1.1.1/lib -Wl,-rpath,/usr/lib/x86_64-linux-gnu/openssh/private"
#LDFLAGS="-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,/usr/lib/x86_64-linux-gnu/openssh/private"
LDFLAGS="-Wl,-z,relro -Wl,--as-needed -Wl,-z,now"
export LDFLAGS

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
git clone "git://anongit.mindrot.org/openssh.git"
cd openssh
_ver=$(grep -i '#define SSH_VERSION' version.h | head -1 | awk '{print $NF}' | sed 's/"//g' | sed 's/OpenSSH_//g')
_port=$(grep -i '#define SSH_PORTABLE' version.h | head -1 | awk '{print $NF}' | sed 's/"//g')
_ssh_ver="${_ver}${_port}"
echo
echo "openssh version: ${_ssh_ver}"
echo
sleep 1
rm -fr .git
rm -fr autom4te.cache
rm -vf config.guess~
rm -vf config.sub~
rm -vf install-sh~
rm -vf configure.ac.orig
rm -vf sshd.c.orig
autoreconf -v -f -i
rm -fr autom4te.cache
rm -vf config.guess~
rm -vf config.sub~
rm -vf install-sh~
rm -vf configure.ac.orig
rm -vf sshd.c.orig
sleep 1

userdel -f -r ssh >/dev/null 2>&1 || : 
userdel -f -r sshd >/dev/null 2>&1 || : 
groupdel ssh >/dev/null 2>&1 || : 
groupdel sshd >/dev/null 2>&1 || : 
sleep 1
getent group sshd >/dev/null || groupadd -g 74 -r sshd || :
getent passwd sshd >/dev/null || \
  useradd -c "Privilege-separated SSH" -u 74 -g sshd \
  -s /usr/sbin/nologin -r -d /var/empty/sshd sshd 2> /dev/null || :

#sed "/^#UsePAM no/i# WARNING: 'UsePAM no' is not supported in Red Hat Enterprise Linux and may cause several\n# problems." -i sshd_config
sed 's|^#UsePAM .*|UsePAM yes|g' -i sshd_config
sed '/^#PrintMotd .*/s|^#PrintMotd .*|\n# It is recommended to use pam_motd in /etc/pam.d/sshd instead of PrintMotd,\n# as it is more configurable and versatile than the built-in version.\nPrintMotd no\n|g' -i sshd_config
sed 's|^#SyslogFacility .*|SyslogFacility AUTHPRIV|' -i sshd_config
sed 's|^#PermitRootLogin .*|PermitRootLogin no|' -i sshd_config

./configure \
--prefix=/usr \
--sysconfdir=/etc/ssh \
--libexecdir=/usr/lib/openssh \
--with-pid-dir=/var/run \
--with-ssl-engine \
--with-pam \
--with-libedit=/usr \
--with-zlib \
--with-ipaddr-display \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu

make -j$(nproc) all
rm -fr /tmp/openssh
make install DESTDIR=/tmp/openssh
install -v -c -m 0755 contrib/ssh-copy-id /tmp/openssh/usr/bin/
install -v -c -m 0644 contrib/ssh-copy-id.1 /tmp/openssh/usr/share/man/man1/

cd /tmp/openssh
install -m 0755 -d etc/ssh
install -m 0755 -d etc/pam.d
install -m 0755 -d usr/lib/systemd/system
install -m 0755 -d etc/systemd/system/sshd.service.d
install -m 0755 -d etc/sysconfig
install -m 0711 -d var/empty/sshd

install -m 0755 -d usr/lib/x86_64-linux-gnu/openssh
sleep 1
cp -af /usr/lib/x86_64-linux-gnu/openssh/private usr/lib/x86_64-linux-gnu/openssh/

sed -e 's|^#PubkeyAuthentication |PubkeyAuthentication |g' -e 's|^PubkeyAuthentication .*|PubkeyAuthentication yes|g' -i etc/ssh/sshd_config
sed -e 's|^#PermitEmptyPasswords |PermitEmptyPasswords |g' -e 's|^PermitEmptyPasswords .*|PermitEmptyPasswords no|g' -i etc/ssh/sshd_config
sed 's|^#PasswordAuthentication .*|#PasswordAuthentication no|g' -i etc/ssh/sshd_config
sed 's|^#KbdInteractiveAuthentication .*|#KbdInteractiveAuthentication no|g' -i etc/ssh/sshd_config
sed 's@^#HostKey /etc/ssh/ssh_host_@HostKey /etc/ssh/ssh_host_@g' -i etc/ssh/sshd_config
sed 's|^HostKey /etc/ssh/ssh_host_dsa_|#&|g' -i etc/ssh/sshd_config
sed 's|^Ciphers |#Ciphers |g' -i etc/ssh/sshd_config
sed 's|^MACs |#MACs |g' -i etc/ssh/sshd_config
sed 's|^KexAlgorithms |#KexAlgorithms |g' -i etc/ssh/sshd_config
sed 's|^PubkeyAcceptedAlgorithms |#PubkeyAcceptedAlgorithms |g' -i etc/ssh/sshd_config
sed 's|^HostKeyAlgorithms |#HostKeyAlgorithms |g' -i etc/ssh/sshd_config
sed 's|^HostbasedAcceptedAlgorithms |#HostbasedAcceptedAlgorithms |g' -i etc/ssh/sshd_config
sleep 1
############################################################################
# Generating hardening options
rm -f etc/ssh/ssh-hardening-options.txt

echo '#' >> etc/ssh/ssh-hardening-options.txt
echo "Ciphers $(./usr/bin/ssh -Q cipher | grep -iE '256.*gcm|gcm.*256|chacha' | paste -sd','),$(./usr/bin/ssh -Q cipher | grep -ivE 'gcm|chacha|cbc' | grep '256' | paste -sd',')" >> etc/ssh/ssh-hardening-options.txt

echo '#' >> etc/ssh/ssh-hardening-options.txt
echo "MACs $(./usr/bin/ssh -Q mac | grep -i 'hmac-sha[23]' | grep -E '256|512' | grep '[0-9]$' | sort -r | paste -sd','),$(./usr/bin/ssh -Q mac | grep -i 'hmac-sha[23]' | grep -E '256|512' | grep '\@' | sort -r | paste -sd',')" >> etc/ssh/ssh-hardening-options.txt

echo '#' >> etc/ssh/ssh-hardening-options.txt
echo "KexAlgorithms $(./usr/bin/ssh -Q kex | grep -iE '25519|448' | grep -iv '\@libssh' | sort -r | paste -sd','),$(./usr/bin/ssh -Q kex | grep -i 'ecdh-sha[23]-nistp5' | sort -r | paste -sd',')" >> etc/ssh/ssh-hardening-options.txt

echo '#' >> etc/ssh/ssh-hardening-options.txt
echo "PubkeyAcceptedAlgorithms $(./usr/bin/ssh -Q PubkeyAcceptedAlgorithms | grep -iE 'ed25519|ed448|sha[23].*nistp521' | grep -v '\@' | paste -sd','),$(./usr/bin/ssh -Q PubkeyAcceptedAlgorithms | grep -iE 'ed25519|ed448|sha[23].*nistp521' | grep '\@' | paste -sd','),$(./usr/bin/ssh -Q PubkeyAcceptedAlgorithms | grep -i 'rsa-' | grep -i 'sha[23]-512' | paste -sd',')" >> etc/ssh/ssh-hardening-options.txt

echo '#' >> etc/ssh/ssh-hardening-options.txt
echo "HostKeyAlgorithms $(./usr/bin/ssh -Q HostKeyAlgorithms | grep -iE 'ed25519|ed448|sha[23].*nistp521' | grep -v '\@' | paste -sd','),$(./usr/bin/ssh -Q HostKeyAlgorithms | grep -iE 'ed25519|ed448|sha[23].*nistp521' | grep '\@' | paste -sd','),$(./usr/bin/ssh -Q HostKeyAlgorithms | grep -i 'rsa-' | grep -i 'sha[23]-512' | paste -sd',')" >> etc/ssh/ssh-hardening-options.txt

echo '#' >> etc/ssh/ssh-hardening-options.txt
echo "HostbasedAcceptedAlgorithms $(./usr/bin/ssh -Q HostbasedAcceptedAlgorithms | grep -iE 'ed25519|ed448|sha[23].*nistp521' | grep -v '\@' | paste -sd','),$(./usr/bin/ssh -Q HostbasedAcceptedAlgorithms | grep -iE 'ed25519|ed448|sha[23].*nistp521' | grep '\@' | paste -sd','),$(./usr/bin/ssh -Q HostbasedAcceptedAlgorithms | grep -i 'rsa-' | grep -i 'sha[23]-512' | paste -sd',')" >> etc/ssh/ssh-hardening-options.txt
############################################################################

sleep 1
mv -f etc/ssh/moduli etc/ssh/moduli.orig
sleep 1
awk '$5 >= 3071' etc/ssh/moduli.orig > etc/ssh/moduli
sleep 1
chmod 0644 etc/ssh/moduli
sed 's|^Subsystem[ \t]*sftp|#&|g' -i etc/ssh/sshd_config
sleep 1
sed '/^#Subsystem.*sftp/aSubsystem\tsftp\tinternal-sftp' -i etc/ssh/sshd_config
sleep 1
cp -pf etc/ssh/sshd_config etc/ssh/sshd_config.default
ln -svf ssh usr/bin/slogin
find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
sleep 2
find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
sleep 2
find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/lib/openssh/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
echo
rm -f etc/pam.d/sshd
rm -f etc/pam.d/sshd.*
echo

# Ubuntu 
############################################################################
echo '# PAM configuration for the Secure Shell service

# Standard Un*x authentication.
@include common-auth

# Disallow non-root logins when /etc/nologin exists.
account    required     pam_nologin.so

# Uncomment and edit /etc/security/access.conf if you need to set complex
# access limits that are hard to express in sshd_config.
# account  required     pam_access.so

# Standard Un*x authorization.
@include common-account

# SELinux needs to be the first session rule.  This ensures that any
# lingering context has been cleared.  Without this it is possible that a
# module could execute code in the wrong domain.
session [success=ok ignore=ignore module_unknown=ignore default=bad]        pam_selinux.so close

# Set the loginuid process attribute.
session    required     pam_loginuid.so

# Create a new session keyring.
session    optional     pam_keyinit.so force revoke

# Standard Un*x session setup and teardown.
@include common-session

# Print the message of the day upon successful login.
# This includes a dynamically generated part from /run/motd.dynamic
# and a static (admin-editable) part from /etc/motd.
session    optional     pam_motd.so  motd=/run/motd.dynamic
session    optional     pam_motd.so noupdate

# Print the status of the user'\''s mailbox upon successful login.
session    optional     pam_mail.so standard noenv # [1]

# Set up user limits from /etc/security/limits.conf.
session    required     pam_limits.so

# Read environment variables from /etc/environment and
# /etc/security/pam_env.conf.
session    required     pam_env.so # [1]
# In Debian 4.0 (etch), locale-related environment variables were moved to
# /etc/default/locale, so read that as well.
session    required     pam_env.so user_readenv=1 envfile=/etc/default/locale

# SELinux needs to intervene at login time to ensure that the process starts
# in the proper default security context.  Only sessions which are intended
# to run in the user'\''s context should be run after this.
session [success=ok ignore=ignore module_unknown=ignore default=bad]        pam_selinux.so open

# Standard Un*x password updating.
@include common-password' > etc/pam.d/sshd
sleep 1
chmod 0644 etc/pam.d/sshd
############################################################################

rm -f usr/lib/systemd/system/ssh.service
rm -f usr/lib/systemd/system/sshd.service
sleep 1
echo '[Unit]
Description=OpenSSH server daemon
Documentation=man:sshd(8) man:sshd_config(5)
After=network.target

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/sshd
ExecStart=/usr/sbin/sshd -D $OPTIONS
ExecStartPost=/bin/sleep 0.1
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target' > usr/lib/systemd/system/sshd.service
chmod 0644 usr/lib/systemd/system/sshd.service
ln -svf sshd.service usr/lib/systemd/system/ssh.service

cp -pf usr/lib/systemd/system/sshd.service etc/ssh/

echo '
cd "$(dirname "$0")"
systemctl disable ssh >/dev/null 2>&1
systemctl disable sshd >/dev/null 2>&1
systemctl disable ssh.socket >/dev/null 2>&1
systemctl disable sshd-keygen.service >/dev/null 2>&1
systemctl disable ssh-agent.service >/dev/null 2>&1

userdel -f -r ssh >/dev/null 2>&1
userdel -f -r sshd >/dev/null 2>&1
groupdel ssh >/dev/null 2>&1
groupdel sshd >/dev/null 2>&1
sleep 1
getent group sshd >/dev/null || groupadd -g 74 -r sshd || :
getent passwd sshd >/dev/null || \
useradd -c "Privilege-separated SSH" -u 74 -g sshd \
-s /usr/sbin/nologin -r -d /var/empty/sshd sshd 2> /dev/null || :
sleep 1
install -m 0711 -d /var/empty/sshd

rm -fr /etc/ssh/ssh_host_*
/usr/bin/ssh-keygen -q -a 200 -t rsa -b 5120 -E sha512 -f /etc/ssh/ssh_host_rsa_key -N "" -C ""
#/usr/bin/ssh-keygen -q -a 200 -t dsa -E sha512 -f /etc/ssh/ssh_host_dsa_key -N "" -C ""
/usr/bin/ssh-keygen -q -a 200 -t ecdsa -b 521 -E sha512 -f /etc/ssh/ssh_host_ecdsa_key -N "" -C ""
/usr/bin/ssh-keygen -q -a 200 -t ed25519 -E sha512 -f /etc/ssh/ssh_host_ed25519_key -N "" -C ""
rm -fr /lib/systemd/system/ssh.service
rm -fr /lib/systemd/system/sshd.service
rm -fr /lib/systemd/system/ssh*.service
rm -f /lib/systemd/system/ssh.socket
rm -f /lib/systemd/system/sshd.socket
sleep 1
install -v -c -m 0644 sshd.service /lib/systemd/system/
sleep 1
ln -svf sshd.service /lib/systemd/system/ssh.service
sleep 1
/bin/systemctl daemon-reload >/dev/null 2>&1 || : 
' > etc/ssh/.install.txt

usr/bin/ssh-keygen -q -a 200 -t rsa -b 5120 -E sha512 -f etc/ssh/ssh_host_rsa_key -N "" -C ""
#usr/bin/ssh-keygen -q -a 200 -t dsa -E sha512 -f etc/ssh/ssh_host_dsa_key -N "" -C ""
usr/bin/ssh-keygen -q -a 200 -t ecdsa -b 521 -E sha512 -f etc/ssh/ssh_host_ecdsa_key -N "" -C ""
usr/bin/ssh-keygen -q -a 200 -t ed25519 -E sha512 -f etc/ssh/ssh_host_ed25519_key -N "" -C ""

if [[ -d usr/sbin ]]; then
    find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/openssh/private' '{}'
fi
if [[ -d usr/bin ]]; then
    find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/openssh/private' '{}'
fi
if [[ -d usr/lib/openssh ]]; then
    find usr/lib/openssh/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\): .*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --add-rpath '$ORIGIN/../../lib/x86_64-linux-gnu/openssh/private' '{}'
fi

rm -fr var/run
rm -fr run
chown -R root:root ./
echo
sleep 2
tar -Jcvf /tmp/"openssh_${_ssh_ver}-1_amd64.tar.xz" *
echo
sleep 2

cd /tmp
rm -fr "${_tmp_dir}"
rm -fr /tmp/openssh
sleep 2
echo
echo ' build openssh done'
echo ' build openssh done' >> /tmp/.done.txt
echo
/sbin/ldconfig
exit

