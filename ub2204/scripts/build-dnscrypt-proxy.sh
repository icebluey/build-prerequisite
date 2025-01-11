#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

/sbin/ldconfig

_install_go () {
    cd /tmp
    rm -fr /tmp/.dl.go.tmp
    mkdir /tmp/.dl.go.tmp
    cd /tmp/.dl.go.tmp
    # Latest version of go
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    # go1.17.X
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.17\.' | tail -n 1)"
    # go1.19.X
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.19\.' | tail -n 1)"

    # go1.21.X
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.21\.' | tail -n 1)"

    # go1.22.X
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.22\.' | tail -n 1)"

    # go1.23.X
    _go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.23\.' | tail -n 1)"

    wget -q -c -t 0 -T 9 "https://dl.google.com/go/go${_go_version}.linux-amd64.tar.gz"
    rm -fr /usr/local/go
    sleep 1
    mkdir /usr/local/go
    tar -xof "go${_go_version}.linux-amd64.tar.gz" --strip-components=1 -C /usr/local/go/
    sleep 1
    cd /tmp
    rm -fr /tmp/.dl.go.tmp
}

_install_go

# Go programming language
export GOROOT='/usr/local/go'
export GOPATH="$GOROOT/home"
export GOTMPDIR='/tmp'
export GOBIN="$GOROOT/bin"
export PATH="$GOROOT/bin:$PATH"
alias go="$GOROOT/bin/go"
alias gofmt="$GOROOT/bin/gofmt"
rm -fr ~/.cache/go-build
echo
go version
echo

set -e

_tmp_dir="$(mktemp -d)"
rm -fr "${GOPATH}"/pkg
sleep 2
mkdir -p "${GOPATH}"/pkg
cd "${_tmp_dir}"

git clone "https://github.com/DNSCrypt/dnscrypt-proxy.git" "dnscrypt-proxy"
#git clone "https://github.com/icebluey/dnscrypt-proxy.git" "dnscrypt-proxy"
echo
sleep 2
cd dnscrypt-proxy

_commit_id="$(git rev-parse --short HEAD)"
#sed '/AppVersion .*=/s|-beta[1-9]||g' -i dnscrypt-proxy/main.go
sed "/AppVersion .*=/s|beta.*|git${_commit_id}\"|g" -i dnscrypt-proxy/main.go

rm -fr .git
cd dnscrypt-proxy

#export GOFLAGS="-buildmode=pie -trimpath -mod=readonly -modcacherw"
export GOFLAGS="-trimpath -mod=readonly -modcacherw"
env CGO_ENABLED=0 go build -o "dnscrypt-proxy" -ldflags "-s -w"

echo
sleep 1
cd ..

rm -fr /tmp/dnscrypt-proxy
rm -fr /tmp/dnscrypt-proxy*.tar*
mkdir /tmp/dnscrypt-proxy

###############################################################################

install -m 0755 -d /tmp/dnscrypt-proxy/usr/bin
install -m 0755 -d /tmp/dnscrypt-proxy/etc/dnscrypt-proxy
install -m 0755 -d /tmp/dnscrypt-proxy/usr/share/licenses/dnscrypt-proxy
install -m 0755 -d /tmp/dnscrypt-proxy/usr/share/dnscrypt-proxy/utils/generate-domains-blocklist
install -m 0755 -d /tmp/dnscrypt-proxy/usr/share/doc/dnscrypt-proxy

# executable
install -vDm 0755 "dnscrypt-proxy/dnscrypt-proxy" -t "/tmp/dnscrypt-proxy/usr/bin/"
# configuration
install -vDm 0644 "dnscrypt-proxy/example-dnscrypt-proxy.toml" \
  "/tmp/dnscrypt-proxy/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
install -vDm 0644 "dnscrypt-proxy/example-allowed-names.txt" \
  "/tmp/dnscrypt-proxy/etc/dnscrypt-proxy/allowed-names.txt"
install -vDm 0644 "dnscrypt-proxy/example-blocked-ips.txt" \
  "/tmp/dnscrypt-proxy/etc/dnscrypt-proxy/blocked-ips.txt"
install -vDm 0644 "dnscrypt-proxy/example-blocked-names.txt" \
  "/tmp/dnscrypt-proxy/etc/dnscrypt-proxy/blocked-names.txt"
install -vDm 0644 "dnscrypt-proxy/example-cloaking-rules.txt" \
  "/tmp/dnscrypt-proxy/etc/dnscrypt-proxy/cloaking-rules.txt"
install -vDm 0644 "dnscrypt-proxy/example-forwarding-rules.txt" \
  "/tmp/dnscrypt-proxy/etc/dnscrypt-proxy/forwarding-rules.txt"

# utils
install -vDm 0644 utils/generate-domains-blocklist/*.{conf,txt} \
  -t "/tmp/dnscrypt-proxy/usr/share/dnscrypt-proxy/utils/generate-domains-blocklist"
install -vDm 0755 utils/generate-domains-blocklist/generate-domains-blocklist.py \
  "/tmp/dnscrypt-proxy/usr/bin/generate-domains-blocklist"
# license
install -vDm 0644 LICENSE -t "/tmp/dnscrypt-proxy/usr/share/licenses/dnscrypt-proxy"
# docs
install -vDm 0644 {ChangeLog,README.md} \
  -t "/tmp/dnscrypt-proxy/usr/share/doc/dnscrypt-proxy"
# pem
install -vDm 0644 "dnscrypt-proxy/localhost.pem" \
  "/tmp/dnscrypt-proxy/etc/dnscrypt-proxy/localhost.pem"

###############################################################################

cd /tmp/dnscrypt-proxy

cp -pf etc/dnscrypt-proxy/dnscrypt-proxy.toml etc/dnscrypt-proxy/dnscrypt-proxy.toml.default
sleep 1

sed "s/^listen_addresses =.*/listen_addresses = \['127.0.0.1:53', '\[::1\]:53'\]/g" -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed 's/^ipv6_servers = .*/ipv6_servers = false/g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed '/^listen_addresses =/i #listen_addresses = \['\''0.0.0.0:53'\''\]' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml

sed 's/^fallback_resolvers/#&/g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed 's/^bootstrap_resolvers/#&/g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml

sed "s/^netprobe_address =.*/netprobe_address = '1.1.1.1:443'/g" -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
#sed '/^# tls_cipher_suite =./atls_cipher_suite = \[4865, 4867, 49195, 49199\]' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed 's/^dnscrypt_servers =.*/dnscrypt_servers = false/g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed "/^# server_names =/aserver_names = \['google', 'cloudflare'\]" -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed 's|^keepalive = .*|keepalive = 7200|g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml

sed 's|^http3 = .*|http3 = true|g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed 's|^# log_level = .*|log_level = 0|g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml

sed 's|refresh_delay = 72|refresh_delay = 24|g' -i etc/dnscrypt-proxy/dnscrypt-proxy.toml

###############################################################################

echo '[Unit]
Description=DNSCrypt-proxy client
Documentation=https://github.com/DNSCrypt/dnscrypt-proxy/wiki
After=network-online.target
Before=nss-lookup.target
Wants=network-online.target nss-lookup.target

[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
#CacheDirectory=dnscrypt-proxy
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
#DynamicUser=yes
ExecStart=/usr/bin/dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
#LockPersonality=yes
#LogsDirectory=dnscrypt-proxy
#MemoryDenyWriteExecute=true
NonBlocking=true
NoNewPrivileges=true
PrivateDevices=true
#ProtectControlGroups=yes
ProtectHome=yes
#ProtectHostname=yes
#ProtectKernelLogs=yes
#ProtectKernelModules=yes
#ProtectKernelTunables=yes
#ProtectSystem=strict
RestrictAddressFamilies=AF_INET AF_INET6
#RestrictNamespaces=true
#RestrictRealtime=true
RuntimeDirectory=dnscrypt-proxy
#StateDirectory=dnscrypt-proxy
SystemCallArchitectures=native
SystemCallFilter=@system-service @chown
#SystemCallFilter=~@resources @privileged

[Install]
WantedBy=multi-user.target' > etc/dnscrypt-proxy/dnscrypt-proxy.service

###############################################################################

echo '[Unit]
Description=DNSCrypt-proxy socket
Documentation=https://github.com/DNSCrypt/dnscrypt-proxy/wiki
Before=nss-lookup.target
Wants=network-online.target nss-lookup.target

[Socket]
ListenStream=127.0.0.1:53
ListenDatagram=127.0.0.1:53
#ListenStream=[::1]:53
#ListenDatagram=[::1]:53
NoDelay=true
DeferAcceptSec=1

[Install]
WantedBy=sockets.target' > etc/dnscrypt-proxy/dnscrypt-proxy.socket

###############################################################################

echo '
cd "$(dirname "$0")"
rm -f /lib/systemd/system/dnscrypt-proxy.s*
sleep 1
install -v -c -m 0644 dnscrypt-proxy.service /lib/systemd/system/
#install -v -c -m 0644 dnscrypt-proxy.socket /lib/systemd/system/
systemctl daemon-reload >/dev/null 2>&1 || : 
echo "nameserver 127.0.0.1" > /etc/resolv.conf
' > etc/dnscrypt-proxy/.install.txt

###############################################################################

chmod 0644 etc/dnscrypt-proxy/dnscrypt-proxy.service
chmod 0644 etc/dnscrypt-proxy/dnscrypt-proxy.socket

_dnscrypt_proxy_ver="$(usr/bin/dnscrypt-proxy --version | cut -d'-' -f1)"
echo
sleep 2
tar -Jcvf "/tmp/dnscrypt-proxy_${_dnscrypt_proxy_ver}-1_static.tar.xz" *
echo
sleep 2
#
###############################################################################

cd /tmp

rm -fr /tmp/dnscrypt-proxy
rm -fr /tmp/dnscrypt-proxy.service
rm -fr /tmp/dnscrypt-proxy.socket
rm -fr "${_tmp_dir}"
rm -fr /usr/local/go
rm -fr ~/.cache/go-build
sleep 2
echo
echo ' build dnscrypt-proxy done'
echo ' build dnscrypt-proxy done' >> /tmp/.done.txt
echo
exit 0

