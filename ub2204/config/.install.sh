#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

set -e

ls -la src/acme.sh/dnsapi >/dev/null 2>&1
ls -la acme.sh >/dev/null 2>&1
echo
mkdir -p ~/.acme.sh
rm -fr ~/.acme.sh/dnsapi
rm -f /usr/local/bin/acme.sh
rm -f /usr/local/bin/gencert-cfapi.sh
cp -pfr src/acme.sh/dnsapi ~/.acme.sh/

install -v -c -m 0755 acme.sh /usr/local/bin/
install -v -c -m 0755 gencert-cfapi.sh /usr/local/bin/

echo
echo ' done'
echo
exit
