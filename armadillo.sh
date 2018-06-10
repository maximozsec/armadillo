#!/bin/bash
#
#	Author  = Mxmzs
#	License = MIT
#

# root check
if [ $EUID -ne 0 ]
	then
		echo "Must run as root!"
		exit
fi

# Exits immediately if a command exits with a non-zero status.
set -e

export PATH=$PATH:`pwd`
srv_conf="/etc/openvpn/server.conf"
dns_srv_conf_1=`cat $srv_conf | grep -i "dhcp-option" | cut -d " " -f4 | cut -d "\"" -f1 | sed -n 1p`
dns_srv_conf_2=`cat $srv_conf | grep -i "dhcp-option" | cut -d " " -f4 | cut -d "\"" -f1 | sed -n 2p`
sysctl_dir="/etc/sysctl.conf"
all_net_interfaces=`ip addr show | cut -d " " -f2 | cut -d ":" -f1`
net_interface=`ip route | grep default | cut -d " " -f5`
net_addr_w_mask=`ip route | grep / | cut -d " " -f1`
vars_dir="/etc/openvpn/easy-rsa/vars"

function ask_port()
{
	read -p "Port number (default 1194): " port

	if [ "$port" -ge 1000 -a "$port" -le 47000 ]; then
			if [ "$port" != 1194 -a "$port" ]; then
					sed -i "s/port 1194/port $port/g" "$srv_conf"
			else
				echo "This is not a valid port number! Try a number a between 1000 and 47000."
				ask_port
			fi
	elif [ -z "$port"  ]; then
		echo "Default port number it is...."
		continue
	else
		echo "This is not a valid port number! Try a number a between 1000 and 47000."
		ask_port
	fi
}

function ask_protocol()
{
	echo ""
	read -p "Protocol (default is UDP): " protocol

	if [ `echo "$protocol" | sed "/([t|T][c|C][p|P])/p"` ]; then
			sed -i "s/proto udp/;proto udp/g" "$srv_conf"
			sed -i "s/;proto tcp/proto tcp/g" "$srv_conf"
	elif [ `echo "$protocol" | sed "/([u|U][d|D][p|P])/p"` ]; then
		continue
	elif [ -z "$protocol" ]; then
		echo "Default port protocol it is...."
		continue
	else
		echo "This is not a valid protocol! Try UDP or TCP."
		ask_protocol
	fi
}

function ask_dns()
{
	echo ""
	read -p "Set custom DNS servers? (y/N): " opt

	if [[ "$opt" == "y" || "$opt" == "Y" ]]; then
			read -p "DNS 1: " dns_1
			read -p "DNS 2: " dns_2
			echo ""
			echo "Setting DNS servers...."

			sed -i "s/DNS $dns_srv_conf_1/DNS $dns_1/g" "$srv_conf"
			sed -i "s/DNS $dns_srv_conf_2/DNS $dns_2/g" "$srv_conf"
	elif [[ "$opt" == "n" || "$opt" == "N" || "$opt" == "" ]]; then
			continue
	exit
	else
		echo "Bad character. Try again."
		ask_dns
	fi
}

function ask_interface()
{
	echo "Network interface detected: $net_interface"
	read -p "Use it? [Y/n] " answer
	
	if [[ "$answer" == "n" || "$answer" == "N" ]]; then
			echo "Showing interfaces:"
			for interface in "$all_net_interfaces"
			do
				echo "$interface"
			done
	elif [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "" ]]; then
			continue
	else
		echo "Bad character. Try again."
		ask_interface
	fi
}

clear

echo ""
echo "Detecting system...."
echo ""
echo "Installing openvpn packages...."

if [ `uname` == "Linux" ]; then
	if [ -f /etc/apt/apt.conf ]; then	
		echo "Debian-based distro detected."
		apt-get install openvpn easy-rsa
	elif [ -f /etc/yum.conf ]; then
		echo "Red Hat based distro detected."
		yum install openvpn easy-rsa
	elif [ -f /etc/pacman.conf ]; then
		echo "Arch Linux based distro detected."
		pacman -S openvpn easy-rsa
	else
		echo "Not supported Linux distro. Sorry...."
	fi
else
	echo "Unable to detect unix-based OS. Exiting...."
	exit
fi

# starts configuration
gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz > /etc/openvpn/server.conf

# HERE IS SERVER.CONF FILE MANIPULATION
echo "Starting configuration...."
echo ""
echo "OpenVPN parameters:"
echo "Hit ENTER for defaults values"
echo ""

sed -i "s/;push \"redirect-gateway def1 bypass-dhcp\"/push \"redirect-gateway def1 bypass-dhcp\"/g" "$srv_conf"
sed -i "s/;push \"dhcp-option DNS $dns_srv_conf_1\"/push \"dhcp-option DNS $dns_srv_conf_1\"/g" "$srv_conf"
sed -i "s/;push \"dhcp-option DNS $dns_srv_conf_2\"/push \"dhcp-option DNS $dns_srv_conf_2\"/g" "$srv_conf"

sed -i "s/;user nobody/user nobody/g" "$srv_conf"
sed -i "s/;group nogroup/group nogroup/g" "$srv_conf"

echo "Setting Diffie-Hellman algorithm from 1024 bits to 2048 bits...."
sed -i "s/dh dh1024.pem/dh dh2048.pem/g" "$srv_conf"
echo ""

ask_port
ask_protocol
ask_dns

# configures ip forward
if [ `cat /proc/sys/net/ipv4/ip_forward` == "0" ]; then
	echo "Enabling ip forwarding...."
	echo 1 > /proc/sys/net/ipv4/ip_forward
fi

# HERE IS SYSCTL.CONF FILE MANIPULATIO

sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g" "$sysctl_dir"

# ----------------------------------------------------------------------- FIREWALL RULES
if [ `ufw status` == "active" ]; then
		set_rules_ufw
elif [ `firewall-cmd --state` == "running" ]; then
		set_rules_firewalld
else
		set_rules_iptables
fi

# ----------------------------------------------------------------------- FIREWALL RULES END

# RSA Keys generations
cp -r /usr/share/easy-rsa /etc/openvpn
mkdir /etc/openvpn/easy-rsa/keys

# HERE IS VARS FILE MANIPULATION
echo "Type your OpenVPN server's information"
echo ""
echo ""

read -p "Country: " k_country
read -p "Province: " k_province
read -p "City: " k_city
read -p "Org: " k_org
read -p "Email: " k_email
read -p "Organizational Unit: " k_ou

sed -i "s/US/$k_country/g" "$vars_dir"
sed -i "s/TX/$k_province/g" "$vars_dir"
sed -i "s/Dallas/$k_city/g" "$vars_dir"
sed -i "s/My Company Name/$k_org/g" "$vars_dir"
sed -i "s/sammy@example.com/$k_email/g" "$vars_dir"
sed -i "s/MyOrganizationalUnit/$k_ou/g" "$vars_dir"
# ENDS FILE MANIPULATION

openssl dhparam -out /etc/openvpn/dh2048.pem 2048

cd /etc/openvpn/easy-rsa
. ./vars
./clean-all

echo "Building ca......"
echo "Just hit ENTER to set the values configured previously"
./build-ca

# generates the server key
echo "Just hit ENTER to set the values configured previously"
./build-key-server server # hit ENTER for default params
						  # choose password (interactive) ou don't
						  # type 'y' on every question

# moving generated server key to openvpn directory
cp /etc/openvpn/easy-rsa/keys/{server.key,{server,ca}.crt} /etc/openvpn

# starts openvpn service
service openvpn start
service openvpn status

# generates the client(s) key
function generate_key()
{
./build-key

}
