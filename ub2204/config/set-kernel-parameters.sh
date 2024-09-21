#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

echo '# Linux kernel 5.8 and later
net.core.default_qdisc = fq_pie
net.ipv4.tcp_congestion_control = bbr
#
net.ipv4.icmp_echo_ignore_all = 1
net.ipv6.icmp.echo_ignore_all = 1
net.core.netdev_max_backlog = 250000
net.core.rmem_default = 65536
net.core.rmem_max = 67108864
net.core.wmem_default = 65536
net.core.wmem_max = 67108864
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 15000 65000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_notsent_lowat = 16384
net.ipv6.conf.all.accept_ra = 2
net.core.somaxconn = 32768
net.netfilter.nf_conntrack_max = 1000000
vm.max_map_count = 655360
fs.file-max = 1048576
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10' > /etc/sysctl.d/999-customize.conf
sleep 1
chmod 0644 /etc/sysctl.d/999-customize.conf

sysctl --system
sleep 1
echo
sysctl -a 2>&1 | grep -i 'net.core.default_qdisc'
sysctl -a 2>&1 | grep -i 'net.ipv4.tcp_congestion_control'
sysctl -a 2>&1 | grep -i 'net.ipv4.tcp_fastopen'
echo
exit

