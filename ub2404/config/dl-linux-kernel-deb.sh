#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

set -e
_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
if [[ -n ${1} ]]; then
    _latest_ver="$(wget -qO- 'https://kernel.ubuntu.com/~kernel-ppa/mainline/' | grep -i '<a href="v[5-9]' | grep -iv '\-rc[1-9]' | sed 's|"|\n|g' | grep '^v[5-9].*/' | sed -e 's|/||g' -e 's|^v||g' | grep "^${1}" | sort -V | uniq | tail -n 1)"
else
    _latest_ver="$(wget -qO- 'https://kernel.ubuntu.com/~kernel-ppa/mainline/' | grep -i '<a href="v[5-9]' | grep -iv '\-rc[1-9]' | sed 's|"|\n|g' | grep '^v[5-9].*/' | sed -e 's|/||g' -e 's|^v||g' | sort -V | uniq | tail -n 1)"
fi
_deblist=$(wget -qO- "https://kernel.ubuntu.com/~kernel-ppa/mainline/v${_latest_ver}/amd64/" | grep '\.deb' | sed 's|"|\n|g' | grep '^linux.*\.deb$' | grep -E 'headers-.*all\.deb|image-unsigned-.*generic|modules-.*generic')
for debfile in ${_deblist}; do wget -c -t 0 -T 9 "https://kernel.ubuntu.com/~kernel-ppa/mainline/v${_latest_ver}/amd64/$debfile"; done
sleep 2
echo
ls -lah --color
echo
cd /tmp
echo
echo ' done '
echo
exit

