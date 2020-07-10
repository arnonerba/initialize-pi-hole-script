#!/usr/bin/env bash

################################################################################
# This bash script is designed to initialize a fresh Ubuntu 18.04+ VPS as a    #
# Pi-hole DNS and/or DHCP server. It also replaces ufw with iptables.          #
################################################################################

if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run as root."
	exit 1
fi

################################################################################
# Step 1: Install iptables and purge all existing rules                        #
################################################################################

apt -y purge ufw
apt -y install iptables iptables-persistent

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

declare -a IPV4_TABLES=("filter" "nat" "mangle" "raw" "security")
for TABLE in "${IPV4_TABLES[@]}"; do
	iptables -t "$TABLE" -F
	iptables -t "$TABLE" -X
done

ip6tables -P INPUT ACCEPT
ip6tables -P FORWARD ACCEPT
ip6tables -P OUTPUT ACCEPT

declare -a IPV6_TABLES=("filter" "raw")
for TABLE in "${IPV6_TABLES[@]}"; do
	ip6tables -t "$TABLE" -F
	ip6tables -t "$TABLE" -X
done

netfilter-persistent save

################################################################################
# Step 2: Configure required firewall rules                                    #
################################################################################

read -p "Enter the name of your server's management interface: " MGMT_INT

iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
iptables -A INPUT -i "$MGMT_INT" -p tcp -m multiport --dports 22 -m state --state NEW -j ACCEPT
iptables -A INPUT -i "$MGMT_INT" -p tcp -m multiport --dports 80 -m state --state NEW -j ACCEPT
iptables -A INPUT -p udp -m multiport --dports 53 -m state --state NEW -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 53 -m state --state NEW -j ACCEPT

while true; do
	read -p "Do you intend to enable DHCP on the Pi-hole? [Y/n] " YN
	case "$YN" in
		[Yy])
			iptables -A INPUT -p udp -m multiport --dports 67:68 -m state --state NEW -j ACCEPT; break ;;
		[Nn])
			break ;;
	esac
done

iptables -P INPUT DROP
iptables -P FORWARD DROP

ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP

netfilter-persistent save

################################################################################
# Step 3: Install and configure Pi-hole                                        #
################################################################################

curl -sSL https://install.pi-hole.net | bash

pihole -a -i local
