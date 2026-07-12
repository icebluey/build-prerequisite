#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

set -e

rm -fr src
mkdir src
cd src
git clone https://github.com/acmesh-official/acme.sh.git
sleep 2
rm -fr acme.sh/.git
rm -fr acme.sh/.github
echo
ls -la acme.sh/acme.sh
rm -fr ../acme.sh
install -m 0755 acme.sh/acme.sh ../acme.sh
cd ..

sed '2iexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/openssl-1.1.1/lib' -i acme.sh
sed '/DEFAULT_OPENSSL_BIN="openssl"$/aDEFAULT_OPENSSL_BIN="/usr/local/openssl-1.1.1/bin/openssl"' -i acme.sh
sed 's/^DEFAULT_OPENSSL_BIN="openssl"/#DEFAULT_OPENSSL_BIN="openssl"/g' -i acme.sh

###############################################################################
#sed '/openssl.* ecparam -name /s| ecparam -name | ecparam -noout -name |g' -i acme.sh

echo
echo ' done'
echo
exit

