#!/bin/bash
VPN_NET=10.13.13.0/24
VPN_NET_6="fd42:42:42:42::/112"  # WG IPv6 sub/net
OUT_DEV=ens33
TUN_DEV=tun0
VPN_DEV=wg0
VPN_PORT=41194
IPV6=false

iptables -t nat -D POSTROUTING -s $VPN_NET -o $OUT_DEV -j MASQUERADE
iptables -D INPUT -i $OUT_DEV -j ACCEPT
iptables -D INPUT -i $VPN_DEV -j ACCEPT
iptables -D INPUT -i $TUN_DEV -j ACCEPT
iptables -D FORWARD -i $VPN_DEV -o $TUN_DEV -j ACCEPT
iptables -D FORWARD -i $TUN_DEV -o $VPN_DEV -j ACCEPT
iptables -D FORWARD -i $OUT_DEV -o $TUN_DEV -j ACCEPT
iptables -D FORWARD -i $TUN_DEV -o $OUT_DEV -j ACCEPT
iptables -D FORWARD -i $OUT_DEV -o $VPN_DEV -j ACCEPT
iptables -D FORWARD -i $VPN_DEV -o $OUT_DEV -j ACCEPT
iptables -D INPUT -i $OUT_DEV -p udp --dport $VPN_PORT -j ACCEPT

# IPv6 rules #
if $IPV6
then
    ip6tables -t nat -D POSTROUTING -s $VPN_NET_6 -o $OUT_DEV -j MASQUERADE
    ip6tables -D INPUT -i $OUT_DEV -j ACCEPT
    ip6tables -D INPUT -i $VPN_DEV -j ACCEPT
    ip6tables -D INPUT -i $TUN_DEV -j ACCEPT
    ip6tables -D FORWARD -i $VPN_DEV -o $TUN_DEV -j ACCEPT
    ip6tables -D FORWARD -i $TUN_DEV -o $VPN_DEV -j ACCEPT
    ip6tables -D FORWARD -i $OUT_DEV -o $TUN_DEV -j ACCEPT
    ip6tables -D FORWARD -i $TUN_DEV -o $OUT_DEV -j ACCEPT
    ip6tables -D FORWARD -i $OUT_DEV -o $VPN_DEV -j ACCEPT
    ip6tables -D FORWARD -i $VPN_DEV -o $OUT_DEV -j ACCEPT
    ip6tables -D INPUT -i $OUT_DEV -p udp --dport $VPN_PORT -j ACCEPT
fi
