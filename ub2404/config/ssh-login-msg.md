
dir /etc/update-motd.d/

```
sed 's|ENABLED=1|ENABLED=0|g' -i /etc/default/motd-news
```
remove
```

 * Ubuntu Pro delivers the most comprehensive open source security and
   compliance features.

   https://ubuntu.com/aws/pro
```


```
# ssh xxx
Welcome to Ubuntu 22.04.5 LTS

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Thu Feb 20 16:46:50 UTC 2025

  System load:           0.2
  Usage of /:            44.2%
  Memory usage:          48%
  Swap usage:            0%
  Processes:             105
  Users logged in:       0

3 updates could not be installed automatically. For more details,
see /var/log/unattended-upgrades/unattended-upgrades.log

Last login: Thu Feb 20 16:44:43 2025 from 


# cat /etc/update-motd.d/92-unattended-upgrades
#!/bin/sh

if [ -x /usr/share/unattended-upgrades/update-motd-unattended-upgrades ]; then
    exec /usr/share/unattended-upgrades/update-motd-unattended-upgrades
fi


# cat /usr/share/unattended-upgrades/update-motd-unattended-upgrades
#!/bin/sh
#
# helper for update-motd

if [ -f /var/lib/unattended-upgrades/kept-back ]; then
  cat <<EOF

$(wc -w < /var/lib/unattended-upgrades/kept-back) updates could not be installed automatically. For more details,
see /var/log/unattended-upgrades/unattended-upgrades.log
EOF
fi

rm -vf /var/lib/unattended-upgrades/kept-back

```
