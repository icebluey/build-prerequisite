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


_private_dir='usr/lib/x86_64-linux-gnu/gnupg/private'

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
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    echo
}

_build_sqlite() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _sqlite_path="$(wget -qO- 'https://www.sqlite.org/download.html' | grep -i '202[4-9]/sqlite-autoconf-[1-9]' | sed 's|,|\n|g' | grep -i '^202[4-9]/sqlite-autoconf-[1-9]')"
    wget -c -t 9 -T 9 "https://www.sqlite.org/${_sqlite_path}"
    tar -xof sqlite-*.tar*
    sleep 1
    rm -f sqlite-*.tar*
    cd sqlite-*
    #LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    sed 's|http://|https://|g' -i configure shell.c sqlite3.1 sqlite3.c sqlite3.h sqlite3.rc
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc \
    --all --enable-math --enable-json --enable-load-extension
    make -j$(nproc --all) all
    rm -fr /tmp/sqlite
    make install DESTDIR=/tmp/sqlite
    cd /tmp/sqlite
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -f /usr/lib/x86_64-linux-gnu/libsqlite3.*
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/sqlite
    /sbin/ldconfig
}

_build_sqlite

###############################################################################

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

for i in libgpg-error libassuan libksba npth ntbtls pinentry gpgme; do
    _tarname=$(wget -qO- https://gnupg.org/ftp/gcrypt/${i}/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)
    wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/${i}/${_tarname}"
done

#_gnupg24_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/gnupg/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^gnupg-2\.4' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
#wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/gnupg/${_gnupg24_tarname}"
#_gnupg23_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/gnupg/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^gnupg-2\.3' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
#wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/gnupg/${_gnupg23_tarname}"
#_gnupg22_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/gnupg/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^gnupg-2\.2' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
#wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/gnupg/${_gnupg22_tarname}"

_gnupg25_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/gnupg/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^gnupg-2\.5' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/gnupg/${_gnupg25_tarname}"

_libgcrypt111_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/libgcrypt/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^libgcrypt-1\.11' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/libgcrypt/${_libgcrypt111_tarname}"

#_libgcrypt110_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/libgcrypt/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^libgcrypt-1\.10' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
#wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/libgcrypt/${_libgcrypt110_tarname}"

#_libgcrypt19_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/libgcrypt/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^libgcrypt-1\.9' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
#wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/libgcrypt/${_libgcrypt19_tarname}"

#_libgcrypt18_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/libgcrypt/ | grep '\.tar\.bz2' | sed 's/href="/ /g' | sed 's/">/ /g' | sed 's/ /\n/g' | grep '^libgcrypt-1\.8' | sed -n '/\.tar\.bz2$/p' | sed -e '/-qt/d' | sort -V | uniq | tail -n 1)"
#wget -c -t 0 -T 9 "https://gnupg.org/ftp/gcrypt/libgcrypt/${_libgcrypt18_tarname}"

sleep 2
ls -1 *.tar* | xargs -I '{}' tar -xof '{}'
sleep 2
rm -f *.tar*

#libgpg-error-1.47
#libassuan-2.5.5
#libksba-1.6.3
#npth-1.6
#libgcrypt-1.10.2
#ntbtls-0.3.1
#pinentry-1.2.1
#gnupg-2.4.1
#gpgme-1.20.0

###############################################################################

cd libgpg-error-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu --enable-shared --enable-static --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libgpg-error
make install DESTDIR=/tmp/libgpg-error
cd /tmp/libgpg-error
install -m 0755 -d usr/include/x86_64-linux-gnu
mv -v -f usr/include/gpg-error.h usr/include/x86_64-linux-gnu/
mv -v -f usr/include/gpgrt.h usr/include/x86_64-linux-gnu/
ln -svf x86_64-linux-gnu/gpg-error.h usr/include/gpg-error.h
ln -svf x86_64-linux-gnu/gpgrt.h usr/include/gpgrt.h
_libgpg_error_ver="$(cat usr/lib/x86_64-linux-gnu/pkgconfig/gpg-error.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
sleep 2
/bin/cp -afr * /
sleep 2
rm -vfr usr/lib/x86_64-linux-gnu/gnupg
echo
sleep 2
tar -Jcvf /tmp/"libgpg-error_${_libgpg_error_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/libgpg-error
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libgpg-error-*
###############################################################################

cd libassuan-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu --enable-shared --enable-static --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libassuan
make install DESTDIR=/tmp/libassuan
cd /tmp/libassuan
_libassuan_ver="$(cat usr/lib/x86_64-linux-gnu/pkgconfig/libassuan.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
sleep 2
/bin/cp -afr * /
sleep 2
rm -vfr usr/lib/x86_64-linux-gnu/gnupg
echo
sleep 2
tar -Jcvf /tmp/"libassuan-${_libassuan_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/libassuan
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libassuan-*
###############################################################################

cd libksba-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu --enable-shared --enable-static --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libksba
make install DESTDIR=/tmp/libksba
cd /tmp/libksba
_libksba_ver="$(cat usr/lib/x86_64-linux-gnu/pkgconfig/ksba.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
sleep 2
/bin/cp -afr * /
sleep 2
rm -vfr usr/lib/x86_64-linux-gnu/gnupg
echo
sleep 2
tar -Jcvf /tmp/"libksba-${_libksba_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/libksba
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libksba-*
###############################################################################

cd npth-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--enable-shared --enable-static \
--enable-install-npth-config \
--prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/npth
make install DESTDIR=/tmp/npth
cd /tmp/npth
#_npth_ver="$(cat usr/lib/x86_64-linux-gnu/pkgconfig/npth.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_npth_ver="$(usr/bin/npth-config --version | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
sleep 2
/bin/cp -afr * /
sleep 2
rm -vfr usr/lib/x86_64-linux-gnu/gnupg
echo
sleep 2
tar -Jcvf /tmp/"npth-${_npth_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/npth
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr npth-*
###############################################################################

cd libgcrypt-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu --enable-shared --enable-static --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libgcrypt
make install DESTDIR=/tmp/libgcrypt
cd /tmp/libgcrypt
_libgcrypt_ver="$(cat usr/lib/x86_64-linux-gnu/pkgconfig/libgcrypt.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
sleep 2
/bin/cp -afr * /
sleep 2
rm -vfr usr/lib/x86_64-linux-gnu/gnupg
echo
sleep 2
tar -Jcvf /tmp/"libgcrypt-${_libgcrypt_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/libgcrypt
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libgcrypt-*
###############################################################################

cd ntbtls-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu --enable-shared --enable-static --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/ntbtls
make install DESTDIR=/tmp/ntbtls
cd /tmp/ntbtls
_ntbtls_ver="$(cat usr/lib/x86_64-linux-gnu/pkgconfig/ntbtls.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
sleep 2
/bin/cp -afr * /
sleep 2
rm -vfr usr/lib/x86_64-linux-gnu/gnupg
echo
sleep 2
tar -Jcvf /tmp/"ntbtls-${_ntbtls_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/ntbtls
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr ntbtls-*
###############################################################################

cd pinentry-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/pinentry
make install DESTDIR=/tmp/pinentry
cd /tmp/pinentry
_pinentry_ver="$(usr/bin/pinentry --version 2>&1 | grep -i '^pinentry.*[0-9]$' | awk '{print $NF}'  | tr -d '\n')"
_strip_files
sleep 2
/bin/cp -afr * /
echo
sleep 2
tar -Jcvf /tmp/"pinentry-${_pinentry_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/pinentry
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr pinentry-*
###############################################################################

# --enable-gpg-is-gpg2 \

cd gnupg-*
./configure \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--enable-wks-tools \
--enable-g13 \
--enable-build-timestamp \
--enable-key-cache=10240 \
--prefix=/usr \
--libexecdir=/usr/lib/gnupg \
--libdir=/usr/lib/x86_64-linux-gnu \
--includedir=/usr/include \
--sysconfdir=/etc \
--localstatedir=/var \
--docdir=/usr/share/doc/gnupg2

make -j$(nproc --all) all

# for v2.4.6
# disable for 2.5
#sed 's|gpgv\.1|gpgv2.1|g' -i doc/Makefile
#sed 's|gpg\.1|gpg2.1|g' -i doc/Makefile

rm -fr /tmp/gnupg
make install DESTDIR=/tmp/gnupg

#install -v -m 0755 -d /tmp/gnupg/usr/lib/systemd/user
#cd doc/examples/systemd-user
#for i in *.*; do
#    install -v -c -m 0644 -D "$i" "/tmp/gnupg/usr/lib/systemd/user/$i"
#done

cd /tmp/gnupg
install -m 0755 -d etc/gnupg
install -m 0755 -d usr/lib/x86_64-linux-gnu/gnupg

echo '# gpg ssh authenticate
[[ -d ~/.gnupg ]] || ( gpg --list-secret-keys >/dev/null 2>&1 || : )
gpgconf --launch gpg-agent >/dev/null 2>&1
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
# fix "gpg: problem with the agent: Inappropriate ioctl for device"
export GPG_TTY="$(tty)"
echo UPDATESTARTUPTTY | gpg-connect-agent >/dev/null 2>&1
# required for gpgv1
export GPG_AGENT_INFO="$(gpgconf --list-dirs agent-socket):0:1"
# create sshcontrol file in ~/.gnupg/
[[ -f ~/.gnupg/sshcontrol ]] || ( ssh-add -L >/dev/null 2>&1 || : )
# "gpg: agent_genkey failed: Permission denied"
# "Key generation failed: Permission denied"
# fix Permission denied issues in root user
chown root:tty "$(tty)" >/dev/null 2>&1 || : ' > etc/gnupg/load_gpg-agent.sh

echo '#keyserver hkps://pgp.mit.edu
keyserver hkps://keyserver.ubuntu.com
expert
no-comments
no-emit-version
keyid-format 0xlong
with-subkey-fingerprint
personal-digest-preferences SHA512 SHA384 SHA256 SHA224
personal-cipher-preferences AES256 AES192 AES
personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
cipher-algo AES256
digest-algo SHA512
cert-digest-algo SHA512
disable-cipher-algo 3DES
weak-digest SHA1
s2k-cipher-algo AES256
s2k-digest-algo SHA512
no-symkey-cache
charset utf-8
require-cross-certification
list-options show-uid-validity
verify-options show-uid-validity
force-aead
aead-algo ocb' > etc/gnupg/gpg.conf

echo '#pinentry-program /usr/bin/pinentry-curses
pinentry-timeout 300
default-cache-ttl 0
max-cache-ttl 0
enable-ssh-support' > etc/gnupg/gpg-agent.conf

#echo 'use-keyboxd' > etc/gnupg/common.conf

echo '#keyserver hkps://pgp.mit.edu
keyserver hkps://keyserver.ubuntu.com' > etc/gnupg/dirmngr.conf

echo '
cd "$(dirname "$0")"
rm -fr /etc/profile.d/load_gpg-agent.sh
sed -e '\''/\/etc\/gnupg\/load_gpg-agent.sh/d'\'' -i ~/.bashrc
sleep 1
install -c -m 0644 load_gpg-agent.sh /etc/profile.d/
echo '\''[[ -f /etc/gnupg/load_gpg-agent.sh ]] && source /etc/gnupg/load_gpg-agent.sh'\'' >> ~/.bashrc
' > etc/gnupg/.install.txt

chmod 0644 etc/gnupg/load_gpg-agent.sh
chmod 0644 etc/gnupg/gpg.conf
chmod 0644 etc/gnupg/gpg-agent.conf
#chmod 0644 etc/gnupg/common.conf
chmod 0644 etc/gnupg/dirmngr.conf
chmod 0644 etc/gnupg/.install.txt

_strip_files

find usr/lib/gnupg/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'

find /usr/lib/x86_64-linux-gnu/gnupg/private/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\): .*ELF.*, .*stripped.*/\1/p' \
  | xargs --no-run-if-empty -I '{}' patchelf --add-rpath '$ORIGIN' '{}'

install -m 0755 -d usr/lib/x86_64-linux-gnu/gnupg
cp -afr /"${_private_dir}" usr/lib/x86_64-linux-gnu/gnupg/

if [[ -d usr/sbin ]]; then
    find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/gnupg/private' '{}'
fi
if [[ -d usr/bin ]]; then
    find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/gnupg/private' '{}'
fi
if [[ -d usr/lib/gnupg ]]; then
    find usr/lib/gnupg/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\): .*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --add-rpath '$ORIGIN/../../lib/x86_64-linux-gnu/gnupg/private' '{}'
fi

sleep 1
ln -svf gpg.1.gz usr/share/man/man1/gpg2.1.gz
ln -svf gpgv.1.gz usr/share/man/man1/gpgv2.1.gz
ln -svf gpg usr/bin/gpg2
ln -svf gpgv usr/bin/gpgv2
[ -f usr/sbin/gpg-zip ] && mv -f usr/sbin/gpg-zip usr/bin/
_gpg_ver="$(./usr/bin/gpg --version 2>&1 | grep -i '^gpg (GnuPG)' | awk '{print $3}')"
echo
sleep 2
/bin/cp -afr * /
sleep 2
tar -Jcvf /tmp/"gnupg-${_gpg_ver}-1_amd64.tar.xz" *
echo
sleep 2
cd /tmp
rm -fr /tmp/gnupg
/sbin/ldconfig

###############################################################################
cd /tmp
rm -fr "${_tmp_dir}"

rm -vf /usr/lib/x86_64-linux-gnu/libsqlite3.a /usr/lib/x86_64-linux-gnu/libsqlite3.so*
apt install -y --reinstall libsqlite3-dev libsqlite3-0

echo
echo ' build gpg done'
echo ' build gpg done' >> /tmp/.done.txt
echo
/sbin/ldconfig
exit
###############################################################################
cd "${_tmp_dir}"
rm -fr gnupg-*
cd gpgme-*

