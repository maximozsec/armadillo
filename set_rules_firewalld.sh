#!/bin/basn

echo "Opening $port/$protocol"
firewall-cmd --add-port "$port"/"$protocol"
firewall-cmd --permanent --add-port "$port"/"$protocol"

echo "Adding masquerade"
firewall-cmd --add-masquerade
firewall-cmd --permanent --add-masquerade

local_ip=`ip route get 8.8.8.8 | awk 'NR==1 {print $(NF-2)}'`
firewall-cmd --permanent --direct --passthrough ipv4 -t nat -A POSTROUTING -s 10.8.0.0/24 -o $local_ip -j MASQUERADE

echo "Reloading FirewallD service"
firewall-cmd --reload
