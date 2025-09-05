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
_tar_ver="$(wget -qO- 'https://mirrors.ocf.berkeley.edu/gnu/tar/' | grep -o 'href="[^"]*\.tar\.xz"' | sed 's/href="//;s/"//' | sed 's/tar-\(.*\)\.tar\.xz/\1/' | grep '^[1-9]' | sort -V | tail -n 1)"
wget -c -t 9 -T 9 "https://mirrors.ocf.berkeley.edu/gnu/tar/tar-${_tar_ver}.tar.xz"
tar -xof "tar-${_tar_ver}.tar.xz"
sleep 1
rm -f "tar-${_tar_ver}.tar.xz"
ls -la --color "tar-${_tar_ver}"

cd lz4
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
make -j$(nproc) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu
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
find usr/lib/x86_64-linux-gnu/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
_lz4_ver="$(LD_LIBRARY_PATH='usr/lib/x86_64-linux-gnu' ./usr/bin/lz4 --version 2>&1 | sed 's/ /\n/g' | grep '^v[1-9]' | sed 's/[vV,]//g')"
echo
sleep 2
tar -Jcvf /tmp/"lz4_${_lz4_ver}-1_amd64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"lz4_${_lz4_ver}-1_amd64.tar.xz" -C /
/sbin/ldconfig
rm -fr /tmp/lz4
cd "${_tmp_dir}"
rm -fr lz4

cd zstd
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
make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C lib lib-mt
make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C programs
make -j$(nproc --all) V=1 prefix=/usr libdir=/usr/lib/x86_64-linux-gnu -C contrib/pzstd
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
find usr/lib/x86_64-linux-gnu/ -type f -iname 'lib*.so.*' -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs -I '{}' strip '{}'
_zstd_ver="$(LD_LIBRARY_PATH='usr/lib/x86_64-linux-gnu' ./usr/bin/zstd --version 2>&1 | sed 's/ /\n/g' | grep '^v[1-9]' | sed 's/[vV,]//g')"
echo
sleep 2
tar -Jcvf /tmp/"zstd_${_zstd_ver}-1_amd64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"zstd_${_zstd_ver}-1_amd64.tar.xz" -C /
/sbin/ldconfig
rm -fr /tmp/zstd

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
make -j$(nproc) all
rm -fr /tmp/tar
rm -fr /tmp/tar*.tar*
make install DESTDIR=/tmp/tar
cd /tmp/tar
mv -f usr/share/man/man8/rmt.8 usr/share/man/man8/rmt-tar.8
mv -f usr/sbin/rmt usr/sbin/rmt-tar
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
tar -Jcvf /tmp/"tar_${_tar_ver}-1_amd64.tar.xz" *
echo
sleep 2
tar -xof /tmp/"tar_${_tar_ver}-1_amd64.tar.xz" -C /
/sbin/ldconfig
rm -fr /tmp/tar

cd /tmp
rm -fr "${_tmp_dir}"
sleep 2
echo
echo ' build compress done'
echo ' build compress done' >> /tmp/.done.txt
echo
/sbin/ldconfig
exit

