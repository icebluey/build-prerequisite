sed 's|.*net.core.default_qdisc=.*|^#&|g' -i /usr/lib/sysctl.d/*.conf
sed 's|.*net.core.default_qdisc .*|^#&|g' -i /usr/lib/sysctl.d/*.conf

tc qdisc replace dev ens160 root fq_pie
chmod +x /etc/rc.d/rc.local

tc qdisc

