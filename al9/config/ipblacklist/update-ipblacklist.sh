#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
set -e

# * * * * * /bin/bash /opt/ipblacklist/update-ipblacklist.sh >/dev/null 2>&1

_update_ipsetlist() {
  rm -fr /tmp/ip-blocklist.txt.tmp
  cat /var/log/secure* 2>&1 | grep -i 'invalid user' | sed 's|.*]: ||g' | sed 's| |\n|g' | \
    grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | \
    sort -V | uniq > /tmp/ip-blocklist.txt.tmp
  cat /var/log/secure* | grep -i 'Unable to negotiate with .* port .*: no matching key exchange method found' | sed 's|.*]: ||g' | sed 's| |\n|g' | \
    grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -V | uniq >> /tmp/ip-blocklist.txt.tmp

  cp -f /opt/ipblacklist/ip-blocklist.txt /opt/ipblacklist/.ip-blocklist.txt."$(date -u +%Y%m%d-%H%M%S)"
  cat /opt/ipblacklist/ip-blocklist.txt >> /tmp/ip-blocklist.txt.tmp
  cat /tmp/ip-blocklist.txt.tmp | \
    sed -e '/^[[:space:]]*$/d' | sed -e 's|[ \t]*$||g' | \
    sed -e '/^54\.163\.206\.189/d' | \
    sed -e '/^45\.77\.159\.33/d' | \
    sed -e '/^127\.0\./d' | \
    sed -e '/^104\.28\.215\./d' | \
    sort -V | uniq > /opt/ipblacklist/ip-blocklist.txt
  sleep 1
  rm -f /tmp/ip-blocklist.txt.tmp
  if [[ $(/bin/ls -1 /opt/ipblacklist/.ip-blocklist.txt.2* 2>/dev/null | wc -l) -gt 3 ]]; then /bin/ls -1 /opt/ipblacklist/.ip-blocklist.txt.2* | head -n 2 | xargs -r -I '{}' rm -vf '{}' ; fi
}

_latest_ip="$(cat /var/log/secure 2>&1 | grep -i 'invalid user' | sed 's|.*]: ||g' | sed 's| |\n|g' | grep -E -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | sed -e '/^54\.163\.206\.189/d' | sed -e '/^45\.77\.159\.33/d' | sed -e '/^127\.0\.0\./d' | tail -n 1)"
if ! /bin/grep -q "${_latest_ip}$" /opt/ipblacklist/ip-blocklist.txt ; then
    _update_ipsetlist
    firewall-cmd --permanent --ipset=blocker --add-entries-from-file="/opt/ipblacklist/ip-blocklist.txt"
    sleep 3
    firewall-cmd --reload
fi
exit
