set -e
_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
wget -c -t 9 -T 9 'https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-amd64'
sleep 1
mv jq-linux-amd64 jq
rm -f /usr/bin/jq
rm -f /usr/local/bin/jq
install -v -c -m 0755 jq /usr/bin/jq
sleep 1
rm -fr jq*

_7zip_loc=$(wget -qO- 'https://www.7-zip.org/download.html' | grep -i '\-linux-x64.tar' | grep -i 'href="' | sed 's|"|\n|g' | grep -i '\-linux-x64.tar' | sort -V | tail -n 1)
_7zip_ver=$(echo ${_7zip_loc} | sed -e 's|.*7z||g' -e 's|-linux.*||g')
wget -c -t 9 -T 9 "https://www.7-zip.org/${_7zip_loc}"
sleep 1
tar -xof *.tar.*
sleep 1
rm -f *.tar*
rm -f /usr/bin/7z
rm -f /usr/local/bin/7z
install -v -c -m 0755 7zzs /usr/bin/7z
sleep 1
cd /tmp
rm -fr "${_tmp_dir}"
exit
