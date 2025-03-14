set -e
_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
_7zip_loc=$(wget -qO- 'https://www.7-zip.org/download.html' | grep -i '\-linux-x64.tar' | grep -i 'href="' | sed 's|"|\n|g' | grep -i '\-linux-x64.tar' | sort -V | tail -n 1)
_7zip_ver=$(echo ${_7zip_loc} | sed -e 's|.*7z||g' -e 's|-linux.*||g')
wget -c -t 9 -T 9 "https://www.7-zip.org/${_7zip_loc}"
sleep 1
tar -xof *.tar.*
sleep 1
rm -f *.tar*

install -v -c -m 0755 7zzs /usr/bin/7z
cd /tmp
sleep 1
rm -fr "${_tmp_dir}"
exit

mkdir /tmp/7-zip-"${_7zip_ver}"-static
install -v -c -m 0755 7zzs /tmp/7-zip-"${_7zip_ver}"-static/7z
cd /tmp
sleep 1
tar -cvf 7-zip-"${_7zip_ver}"-static.tar 7-zip-"${_7zip_ver}"-static
sleep 1
rm -fr "${_tmp_dir}"
rm -fr /tmp/7-zip-"${_7zip_ver}"-static
exit

