#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

#red color
# echo -e "\n\033[01;31m"''"\033[00m\n"
#green color
# echo -e "\n\033[01;32m"''"\033[00m\n"

###############################################################################

_domain_name="${1}"

if [[ -z "${_domain_name}" ]]; then
    echo 'Usage: '"$0"" 'domain.com'"
    exit 1
fi

###############################################################################

if [[ ! -f /usr/local/bin/acme.sh ]]; then
    echo -e "\n\033[01;31m"'no file: /usr/local/bin/acme.sh'"\033[00m\n"
    exit 1
fi

if [[ ! -f /usr/bin/wget ]]; then
    echo -e "\n\033[01;31m"'no file: /usr/bin/wget'"\033[00m\n"
    exit 1
fi

if [[ ! -d ~/.acme.sh/dnsapi ]]; then
    echo -e "\n\033[01;31m"'no dir:  ~/.acme.sh/dnsapi'"\033[00m\n"
    exit 1
fi

_OPENSSL_BIN='/usr/local/openssl-1.1.1/bin/openssl'
"${_OPENSSL_BIN:-openssl}" version 2>&1
rc=$?
if [[ $rc != 0 ]]; then
    echo -e "\n\033[01;31m"'openssl not installed'"\033[00m\n"
    exit 1
fi
echo

###############################################################################

/bin/rm -fr /tmp/.acme.sh.dnsapi.tmp
mkdir /tmp/.acme.sh.dnsapi.tmp
mv -f ~/.acme.sh/dnsapi /tmp/.acme.sh.dnsapi.tmp/
sleep 1
/bin/rm -fr ~/.acme.sh
mkdir ~/.acme.sh
mv -f /tmp/.acme.sh.dnsapi.tmp/dnsapi ~/.acme.sh/
sleep 1
/bin/rm -fr /tmp/.acme.sh.dnsapi.tmp

###############################################################################

read -p 'Email: ' _email
read -sp 'Global API Key: ' _api_key
_email="$(echo "${_email}" | sed 's/ //g')"
_api_key="$(echo "${_api_key}" | sed 's/ //g')"

export CF_Email="${_email}"
export CF_Key="${_api_key}"

echo
/usr/local/bin/acme.sh --set-default-ca --server letsencrypt
echo
###############################################################################

/usr/local/bin/acme.sh \
--issue \
--ocsp-must-staple \
-d "${_domain_name}" \
-d *."${_domain_name}" \
--dns dns_cf \
-k ec-384 \
--preferred-chain "ISRG Root X1"

###############################################################################

rc=$?
if [[ $rc != 0 ]]; then
    exit 1
fi
echo
echo -e "\n\033[01;32m"'  Issue Succeeded'"\033[00m\n"
echo

[ -f ~/.acme.sh/account.conf ] && sed -e '/_Key=/d' -i ~/.acme.sh/account.conf
[ -f ~/.acme.sh/account.conf ] && sed -e '/_Email=/d' -i ~/.acme.sh/account.conf

_suffix="$(head -1 /dev/urandom | sha512sum | cut -c '5-21')"
[ -d ~/.ssl ] && mv -f -v ~/.ssl /tmp/.ssl.bak."${_suffix}"
sleep 1
mkdir ~/.ssl

###############################################################################

/usr/local/bin/acme.sh \
--installcert \
-d "${_domain_name}" \
-d *."${_domain_name}" \
--fullchain-file /root/.ssl/cert.crt \
--key-file /root/.ssl/privkey.pem \
--ecc 

###############################################################################

rc=$?
if [[ $rc != 0 ]]; then
    if [[ -d /tmp/.ssl.bak.${_suffix} ]]; then
        rm -fr ~/.ssl
        echo ' Restore ~/.ssl dir'
        sleep 1
        mv -f -v /tmp/.ssl.bak."${_suffix}" ~/.ssl        
    fi
    exit 1
fi

###############################################################################

echo
echo '####################################################'
echo '#'
echo '# Post-installation'
echo '#'
echo '####################################################'
echo

cd ~/.ssl/

###############################################################################

/bin/rm -fr /etc/letsencrypt /var/log/letsencrypt ~/.local/share/letsencrypt
/bin/rm -fr pubkey.pem dhparam.pem
/bin/rm -f lets-encrypt*cross-signed.pem

###############################################################################

mv -f privkey.pem privkey.orig.pem
sleep 1
"${_OPENSSL_BIN:-openssl}" pkcs8 -in privkey.orig.pem -topk8 -nocrypt -out privkey.pem
sleep 1
/bin/rm -f privkey.orig.pem

###############################################################################

"${_OPENSSL_BIN:-openssl}" dhparam -dsaparam -out dhparam.pem 4096 >/dev/null 2>&1
sleep 5
"${_OPENSSL_BIN:-openssl}" dhparam -check -in dhparam.pem 2>&1 | head -n 1

###############################################################################

### https://letsencrypt.org/certificates/
# openssl x509 -noout -text -in cert.pem
echo
wget -c -t 0 -T 9 \
'https://letsencrypt.org/certs/lets-encrypt-r3-cross-signed.pem'
echo

###############################################################################

chmod 0644 lets-encrypt*.pem
chmod 0600 privkey*
echo -e "\n\033[01;32m"'  Install Succeeded'"\033[00m\n"
/bin/rm -fr /tmp/.ssl.bak."${_suffix}"

exit 0

