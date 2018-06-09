#!/bin/bash
#
#	Author  = Mxmzs
#	License = MIT
#

ufw_dir="/etc/default/ufw"
before_rules_dir="/etc/ufw/before.rules"

ufw status
ufw allow ssh
ufw allow "$port"/"$protocol"

sed -i "s/DEFAULT_FORWARD_POLICY=\"DROP\"/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/g" "$ufw_dir"

cat <<RULES >> "$before_rules_dir"
\# OPENVPN RULES
\# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

\# Allow traffic from OpenVPN client to eth0
-A POSTROUTING -s "$net_addr_w_mask" -o "$net_interface" -j MASQUERADE
COMMIT
RULES

echo "Enabling ufw...."
ufw enable
ufw status
