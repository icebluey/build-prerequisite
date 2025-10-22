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
_private_dir='usr/lib64/gnupg/private'

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
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        find -L usr/share/man/ -type l | while read file; do ln -sf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    for libroot in usr/lib/x86_64-linux-gnu usr/lib64; do
        [[ -d "$libroot" ]] || continue
        find "$libroot" -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find "$libroot" -type f -iname 'lib*.so*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find "$libroot" -type f -iname '*.so' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    done
    for binroot in usr/sbin usr/bin; do
        [[ -d "$binroot" ]] || continue
        find "$binroot" -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    done
    libroot=''
    binroot=''
}

_build_zlib() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --64
    make -j$(nproc --all) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib64/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib64/libz.so*
    /bin/rm -f /usr/lib64/libz.a
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_sqlite() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _sqlite_path="$(wget -qO- 'https://www.sqlite.org/download.html' | grep -i '20[2-9][4-9]/sqlite-autoconf-[1-9]' | sed 's|,|\n|g' | grep -i '^20[2-9][4-9]/sqlite-autoconf-[1-9]')"
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
    --all --enable-math --enable-json --enable-load-extension \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/sqlite
    make install DESTDIR=/tmp/sqlite
    cd /tmp/sqlite
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib64/*.so* "${_private_dir}"/
    rm -f /usr/lib64/libsqlite3.*
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/sqlite
    /sbin/ldconfig
}

# backup orig sqlite
mkdir /tmp/.sqlite.orig
/bin/cp -af /usr/lib64/libsqlite3.* /tmp/.sqlite.orig/

rm -fr /usr/lib64/gnupg/private
_build_zlib
_build_sqlite
###############################################################################
_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
for i in libgpg-error libassuan libksba npth pinentry ntbtls; do
    _tarname=$(wget -qO- https://gnupg.org/ftp/gcrypt/${i}/ | sed -n 's/.*href="\([^"]*\.tar\.bz2\)".*/\1/p' | grep -v -- '-qt' | sort -V | tail -1)
    [[ -n "$_tarname" ]] && wget -c -t 9 -T 9 "https://gnupg.org/ftp/gcrypt/${i}/${_tarname}"
done
_libgcrypt111_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/libgcrypt/ | sed -n 's/.*href="\([^"]*\.tar\.bz2\)".*/\1/p' | grep -v -- '-qt' | sort -V | tail -1)"
wget -c -t 9 -T 9 "https://gnupg.org/ftp/gcrypt/libgcrypt/${_libgcrypt111_tarname}"
_gnupg25_tarname="$(wget -qO- https://gnupg.org/ftp/gcrypt/gnupg/ | sed -n 's/.*href="\([^"]*\.tar\.bz2\)".*/\1/p' | grep -v -- '-qt' | grep '2\.5\.' | sort -V | tail -1)"
wget -c -t 9 -T 9 "https://gnupg.org/ftp/gcrypt/gnupg/${_gnupg25_tarname}"
sleep 1
ls -1 *.tar* | xargs -I '{}' tar -xof '{}'
sleep 1
rm -f *.tar*
# libgpg-error
# libassuan
# libksba
# npth
# libgcrypt
# ntbtls
# pinentry
# gnupg
###############################################################################

cd libgpg-error-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--enable-shared --enable-static \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libgpg-error
make install DESTDIR=/tmp/libgpg-error
cd /tmp/libgpg-error
_libgpg_error_ver="$(cat usr/lib64/pkgconfig/gpg-error.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib64/*.so* "${_private_dir}"/
sleep 1
/bin/cp -afr * /
sleep 1
rm -vfr usr/lib64/gnupg
echo
sleep 1
tar -Jcvf /tmp/"libgpg-error_${_libgpg_error_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/libgpg-error
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libgpg-error-*
###############################################################################

cd libassuan-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--enable-shared --enable-static \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libassuan
make install DESTDIR=/tmp/libassuan
cd /tmp/libassuan
_libassuan_ver="$(cat usr/lib64/pkgconfig/libassuan.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib64/*.so* "${_private_dir}"/
sleep 1
/bin/cp -afr * /
sleep 1
rm -vfr usr/lib64/gnupg
echo
sleep 1
tar -Jcvf /tmp/"libassuan-${_libassuan_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/libassuan
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libassuan-*
###############################################################################

cd libksba-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--enable-shared --enable-static \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libksba
make install DESTDIR=/tmp/libksba
cd /tmp/libksba
_libksba_ver="$(cat usr/lib64/pkgconfig/ksba.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib64/*.so* "${_private_dir}"/
sleep 1
/bin/cp -afr * /
sleep 1
rm -vfr usr/lib64/gnupg
echo
sleep 1
tar -Jcvf /tmp/"libksba-${_libksba_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/libksba
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libksba-*
###############################################################################

cd npth-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--enable-shared --enable-static \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc \
--enable-install-npth-config
make -j$(nproc --all) all
rm -fr /tmp/npth
make install DESTDIR=/tmp/npth
cd /tmp/npth
_npth_ver="$(usr/bin/npth-config --version | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib64/*.so* "${_private_dir}"/
sleep 1
/bin/cp -afr * /
sleep 1
rm -vfr usr/lib64/gnupg
echo
sleep 1
tar -Jcvf /tmp/"npth-${_npth_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/npth
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr npth-*
###############################################################################

cd libgcrypt-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--enable-shared --enable-static \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/libgcrypt
make install DESTDIR=/tmp/libgcrypt
cd /tmp/libgcrypt
_libgcrypt_ver="$(cat usr/lib64/pkgconfig/libgcrypt.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib64/*.so* "${_private_dir}"/
sleep 1
/bin/cp -afr * /
sleep 1
rm -vfr usr/lib64/gnupg
echo
sleep 1
tar -Jcvf /tmp/"libgcrypt-${_libgcrypt_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/libgcrypt
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr libgcrypt-*
###############################################################################

cd ntbtls-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--enable-shared --enable-static \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/ntbtls
make install DESTDIR=/tmp/ntbtls
cd /tmp/ntbtls
_ntbtls_ver="$(cat usr/lib64/pkgconfig/ntbtls.pc | grep -i '^Version' | awk '{print $NF}' | tr -d '\n')"
_strip_files
install -m 0755 -d "${_private_dir}"
cp -af usr/lib64/*.so* "${_private_dir}"/
sleep 1
/bin/cp -afr * /
sleep 1
rm -vfr usr/lib64/gnupg
echo
sleep 1
tar -Jcvf /tmp/"ntbtls-${_ntbtls_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/ntbtls
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr ntbtls-*
###############################################################################

cd pinentry-*
./configure --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
--prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
make -j$(nproc --all) all
rm -fr /tmp/pinentry
make install DESTDIR=/tmp/pinentry
cd /tmp/pinentry
_pinentry_ver="$(usr/bin/pinentry --version 2>&1 | grep -i '^pinentry.*[0-9]$' | awk '{print $NF}'  | tr -d '\n')"
_strip_files
sleep 1
/bin/cp -afr * /
sleep 1
if [[ -d usr/sbin ]]; then
    find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --force-rpath --add-rpath '$ORIGIN/../lib64/gnupg/private' '{}'
fi
if [[ -d usr/bin ]]; then
    find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --force-rpath --add-rpath '$ORIGIN/../lib64/gnupg/private' '{}'
fi
echo
sleep 1
tar -Jcvf /tmp/"pinentry-${_pinentry_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/pinentry
/sbin/ldconfig
cd "${_tmp_dir}"
rm -fr pinentry-*
###############################################################################

cd gnupg-*

# patch
#rm -f /tmp/p*.patch
#wget 'https://git.gnupg.org/cgi-bin/gitweb.cgi?p=gnupg.git;a=patch;h=a73c88817ce2dc05d4eefc2a8f31b89504523a9a' -O /tmp/p01.patch
#ls -1 /tmp/p*.patch | xargs -I '{}' patch -N -p1 -i '{}'
#rm -f /tmp/p*.patch

./configure \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--enable-wks-tools \
--enable-g13 \
--enable-build-timestamp \
--enable-key-cache=10240 \
--enable-large-secmem \
--prefix=/usr \
--libexecdir=/usr/libexec \
--libdir=/usr/lib64 \
--includedir=/usr/include \
--sysconfdir=/etc \
--localstatedir=/var \
--docdir=/usr/share/doc/gnupg2
make -j$(nproc --all) all
rm -fr /tmp/gnupg
make install DESTDIR=/tmp/gnupg
cd /tmp/gnupg
install -m 0755 -d etc/gnupg

echo '[[ -d ~/.gnupg ]] || ( gpg --list-secret-keys >/dev/null 2>&1 || : )
gpgconf --launch gpg-agent >/dev/null 2>&1
# gpg ssh authenticate
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
chown root:tty "$(tty)" >/dev/null 2>&1 || : 
' > etc/gnupg/load_gpg-agent.sh

echo '#keyserver hkps://pgp.mit.edu
keyserver hkps://keyserver.ubuntu.com
display-charset utf-8
utf8-strings
expert
no-comments
no-emit-version
no-greeting
no-symkey-cache
keyid-format 0xlong
with-subkey-fingerprint
personal-digest-preferences SHA512 SHA384 SHA256 SHA224
personal-cipher-preferences AES256 AES192 AES
personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
default-preference-list SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
cipher-algo AES256
digest-algo SHA512
cert-digest-algo SHA512
disable-cipher-algo IDEA
disable-cipher-algo 3DES
disable-cipher-algo CAST5
disable-cipher-algo BLOWFISH
disable-cipher-algo TWOFISH
disable-pubkey-algo ELG
disable-pubkey-algo DSA
weak-digest SHA1
s2k-cipher-algo AES256
s2k-digest-algo SHA512
require-cross-certification
require-secmem
list-options show-uid-validity
verify-options show-uid-validity
force-ocb
no-auto-key-upload
trust-model tofu+pgp' > etc/gnupg/gpg.conf

echo '#pinentry-program /usr/bin/pinentry-curses
pinentry-timeout 300
default-cache-ttl 0
max-cache-ttl 0
enable-ssh-support' > etc/gnupg/gpg-agent.conf

echo '#keyserver hkps://pgp.mit.edu
keyserver hkps://keyserver.ubuntu.com' > etc/gnupg/dirmngr.conf

#echo 'use-keyboxd' > etc/gnupg/common.conf

echo '
cd "$(dirname "$0")"
rm -fr /etc/profile.d/load_gpg-agent.sh
sed -e '\''/\/etc\/gnupg\/load_gpg-agent.sh/d'\'' -i ~/.bashrc
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

install -m 0755 -d usr/lib64/gnupg
cp -afr /"${_private_dir}" usr/lib64/gnupg/

if [[ -d usr/sbin ]]; then
    find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --force-rpath --add-rpath '$ORIGIN/../lib64/gnupg/private' '{}'
fi
if [[ -d usr/bin ]]; then
    find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --force-rpath --add-rpath '$ORIGIN/../lib64/gnupg/private' '{}'
fi
if [[ -d usr/libexec ]]; then
    find usr/libexec/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    find usr/libexec/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\): .*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --force-rpath --add-rpath '$ORIGIN/../lib64/gnupg/private' '{}'
fi
if [[ -d usr/lib64/gnupg/private ]]; then
    find usr/lib64/gnupg/private/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\): .*ELF.*, .*stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' patchelf --force-rpath --add-rpath '$ORIGIN' '{}'
fi

sleep 1
ln -svf gpg.1.gz usr/share/man/man1/gpg2.1.gz
ln -svf gpgv.1.gz usr/share/man/man1/gpgv2.1.gz
ln -svf gpg usr/bin/gpg2
ln -svf gpgv usr/bin/gpgv2
[ -f usr/sbin/gpg-zip ] && mv -f usr/sbin/gpg-zip usr/bin/
_gpg_ver="$(./usr/bin/gpg --version 2>&1 | grep -i '^gpg (GnuPG)' | awk '{print $3}')"
echo
sleep 1
/bin/cp -afr * /
sleep 1
tar -Jcvf /tmp/"gnupg-${_gpg_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 1
cd /tmp
rm -fr /tmp/gnupg
/sbin/ldconfig
###############################################################################

cd /tmp
rm -fr "${_tmp_dir}"

if ls /tmp/.sqlite.orig/libsqlite3.* >/dev/null 2>&1; then rm -vf /usr/lib64/libsqlite3.*; /bin/cp -afv /tmp/.sqlite.orig/libsqlite3.* /usr/lib64/; fi
sleep 1
rm -fr /tmp/.sqlite.orig

/sbin/ldconfig
echo
echo ' build gpg bundle done'
echo
exit
