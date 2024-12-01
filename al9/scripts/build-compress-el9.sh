#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

#https://github.com/lz4/lz4.git
#https://github.com/facebook/zstd.git

/sbin/ldconfig

CC=gcc
export CC
CXX=g++
export CXX

set -e

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

git clone "https://github.com/lz4/lz4.git"
git clone "https://github.com/facebook/zstd.git"
_tar_ver="$(wget -qO- 'https://ftp.gnu.org/gnu/tar/' | grep -i 'href="tar-[1-9].*\.tar' | sed 's/"/\n/g' | grep -i '^tar-[1-9].*\.tar\.xz$' | sort -V | tail -n 1 | sed -e 's|tar-||g' -e 's|\.tar.*||g')"
wget -c -t 0 -T 9 "https://ftp.gnu.org/gnu/tar/tar-${_tar_ver}.tar.xz"
tar -xof "tar-${_tar_ver}.tar.xz"
sleep 1
rm -f "tar-${_tar_ver}.tar.xz"
ls -la --color "tar-${_tar_ver}"
###############################################################################

cd lz4
sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i Makefile
sed '/^prefix/s|= .*|= /usr|g' -i Makefile
sed '/^libdir/s|= .*|= /usr/lib64|g' -i Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i lib/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
sed '/^libdir/s|= .*|= /usr/lib64|g' -i lib/Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
#sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i programs/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
#sed '/^libdir/s|= .*|= /usr/lib64|g' -i programs/Makefile
sleep 1
make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib64
rm -fr /tmp/lz4
rm -fr /tmp/lz4*.tar*
make install DESTDIR=/tmp/lz4
cd /tmp/lz4
find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
sleep 2
find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
sleep 2
find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/lib64/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
_lz4_ver="$(LD_LIBRARY_PATH='usr/lib64' ./usr/bin/lz4 --version 2>&1 | sed 's/ /\n/g' | grep '^v[1-9]' | sed 's/[vV,]//g')"
echo
sleep 2
tar -Jcvf /tmp/"lz4-${_lz4_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"lz4-${_lz4_ver}-1.el9.x86_64.tar.xz" -C /
/sbin/ldconfig
rm -fr /tmp/lz4
cd "${_tmp_dir}"
rm -fr lz4
###############################################################################

cd zstd
sed '/^PREFIX/s|= .*|= /usr|g' -i Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i Makefile
sed '/^prefix/s|= .*|= /usr|g' -i Makefile
sed '/^libdir/s|= .*|= /usr/lib64|g' -i Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i lib/Makefile
sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i lib/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i lib/Makefile
sed '/^libdir/s|= .*|= /usr/lib64|g' -i lib/Makefile
sed '/^PREFIX/s|= .*|= /usr|g' -i programs/Makefile
#sed '/^LIBDIR/s|= .*|= /usr/lib64|g' -i programs/Makefile
sed '/^prefix/s|= .*|= /usr|g' -i programs/Makefile
#sed '/^libdir/s|= .*|= /usr/lib64|g' -i programs/Makefile
sleep 1
make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib64 -C lib lib-mt
make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib64 -C programs
make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib64 -C contrib/pzstd
rm -fr /tmp/zstd
rm -fr /tmp/zstd*.tar*
make install DESTDIR=/tmp/zstd
install -v -c -m 0755 contrib/pzstd/pzstd /tmp/zstd/usr/bin/
cd /tmp/zstd
ln -svf zstd.1 usr/share/man/man1/pzstd.1
find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
sleep 2
find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
sleep 2
find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/lib64/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
_zstd_ver="$(LD_LIBRARY_PATH='usr/lib64' ./usr/bin/zstd --version 2>&1 | sed 's/ /\n/g' | grep '^v[1-9]' | sed 's/[vV,]//g')"
echo
sleep 2
tar -Jcvf /tmp/"zstd-${_zstd_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"zstd-${_zstd_ver}-1.el9.x86_64.tar.xz" -C /
/sbin/ldconfig
rm -fr /tmp/zstd
###############################################################################

cd "${_tmp_dir}"
rm -fr zstd
cd "tar-${_tar_ver}"
./configure DEFAULT_ARCHIVE_FORMAT=GNU FORCE_UNSAFE_CONFIGURE=1 \
--build=x86_64-linux-gnu \
--host=x86_64-linux-gnu \
--prefix=/usr \
--sysconfdir=/etc \
--libexecdir=/usr/sbin \
--with-xz=/usr/bin/xz \
--with-zstd=/usr/bin/zstd \
--with-gzip=/bin/gzip \
--with-bzip2=/bin/bzip2
make -j$(nproc --all) all
rm -fr /tmp/tar
rm -fr /tmp/tar*.tar*
make install DESTDIR=/tmp/tar
cd /tmp/tar

ln -svf tar usr/bin/gtar
ln -svf tar.1 /usr/share/man/man1/gtar.1

#mv -f usr/share/man/man8/rmt.8 usr/share/man/man8/rmt-tar.8
#mv -f usr/sbin/rmt usr/sbin/rmt-tar
#rm -f usr/sbin/rmt
#rm -f usr/share/man/man8/rmt.8

find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
sleep 2
find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
sleep 2
find -L usr/share/man/ -type l -exec rm -f '{}' \;
find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
_tar_ver="$(./usr/bin/tar --version 2>&1 | head -1 | awk '{print $NF}')"
echo
sleep 2
tar -Jcvf /tmp/"tar-${_tar_ver}-1.el9.x86_64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"tar-${_tar_ver}-1.el9.x86_64.tar.xz" -C /
/sbin/ldconfig
rm -fr /tmp/tar
###############################################################################

cd /tmp
rm -fr "${_tmp_dir}"
sleep 2
echo
echo ' build compress done'
echo ' build compress done' >> /tmp/.done.txt
echo
/sbin/ldconfig
exit

