#!/bin/bash
set -e

# set defaults
default_hostname="$(hostname)"
default_domain=""
tmp="/root/"

#networking defaults 77 and DMZ Networks
default_c_address="192.168.1"
default_netmask="255.255.255"
default_dns_nameservers="$default_c_address.20 $default_c_address.18"
default_dns_search="paspx.com"

clear

# check for root privilege
if [ "$(id -u)" != "0" ]; then
   echo " this script must be run as root" 1>&2
   echo
   exit 1
fi

# define download function
# courtesy of http://fitnr.com/showing-file-download-progress-using-wget.html
download()
{
    local url=$1
    echo -n "    "
    wget --progress=dot $url 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    echo -ne "\b\b\b\b"
    echo " DONE"
}

# determine ubuntu version
ubuntu_version=$(lsb_release -cs)

# check for interactive shell
if ! grep -q "noninteractive" /proc/cmdline ; then
    stty sane

    # ask questions
    read -ep " please enter your preferred hostname: " -i "$default_hostname" hostname
    read -ep " please enter your preferred domain: " -i "$default_domain" domain
fi

# print status message
echo " preparing your server; this may take a few minutes ..."

# set fqdn
fqdn="$hostname.$domain"

# update hostname
echo "$hostname" > /etc/hostname
sed -i "s@ubuntu.ubuntu@$fqdn@g" /etc/hosts
sed -i "s@ubuntu@$hostname@g" /etc/hosts
hostname "$hostname"

# Update Internet
# Static IP
read -ep "Configure Static IP? " -i "yes" staticip

if [[ $staticip == "yes" ]] || [[ $staticip == "y" ]]; then
	read -ep "Set Default C Address (192.168.1): " -i "$default_c_address" caddress
	echo "Select Network Device"
	ETH=(`ifconfig -a | sed 's/[ \t].*//;/^$/d'`)
	select slceth in "${ETH[@]}"; do
	  case $slceth in
	    *)
	      echo "$slceth selected"
			ethadap=$slceth
		break
	      ;;
	  esac
	done
	if [[ $caddress  == "94.18.208" ]]; then
		read -ep "Set Static IP ($caddress.19): " -i "$caddress." ipaddress
		read -ep "Set Netmask (255.255.255.128): " -i "$default_netmask.128" netmask
		read -ep "Set Nameservers (Seperate with Space): " -i "$default_dns_nameservers" nameservers
		read -ep "Set DNS Search: " -i "$default_dns_search" dnssearch

		read -ep "Set Network Address ($caddress.0): " -i "$caddress.0" network
		read -ep "Set Broadcast (94.18.209.1): " -i "94.18.209.1" broadcast
		read -ep "Set Gateway ($caddress.1): " -i "$caddress.1" gateway
	else
		read -ep "Set Static IP ($caddress.19): " -i "$caddress." ipaddress
		read -ep "Set Netmask (255.255.255.0): " -i "$default_netmask.0" netmask
		read -ep "Set Nameservers (Seperate with Space): " -i "$default_dns_nameservers" nameservers
		read -ep "Set DNS Search: " -i "$default_dns_search" dnssearch

		read -ep "Set Network Address ($caddress.0): " -i "$caddress.0" network
		read -ep "Set Broadcast ($caddress.255): " -i "$caddress.255" broadcast
		read -ep "Set Gateway ($caddress.1): " -i "$caddress.1" gateway
	fi
fi

echo '' > /etc/network/interfaces

cat >/etc/network/interfaces <<EOL
source /etc/network/interfaces.d/*
 
auto lo
iface lo inet loopback
 
auto ${ethadap}
iface ${ethadap} inet static
	address     ${ipaddress}
        netmask     ${netmask}
        network     ${network}
        broadcast   ${broadcast}
        gateway     ${gateway}
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers ${nameservers}
        dns-search ${dnssearch}
EOL

# update repos
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get -y purge

#Install Stuff
apt-get -y install dnsutils
apt-get -y install ufw
apt-get -y install ed
apt-get -y install ntfs-3g
apt-get -y install ubuntu-release-upgrader-core
#Host Commands
apt-get -y install bind9-host
#Traceroute
apt-get -y install mtr-tiny
apt-get -y install bash-completion
apt-get -y install mlocate
apt-get -y install install-info
apt-get -y install irqbalance
apt-get -y install language-selector-common
apt-get -y install friendly-recovery
apt-get -y install command-not-found
apt-get -y install info
apt-get -y install lshw
apt-get -y install update-manager-core
apt-get -y install apt-transport-https
apt-get -y install accountsservice
apt-get -y install command-not-found-data
apt-get -y install time
apt-get -y install ltrace
apt-get -y install parted
apt-get -y install strace
apt-get -y install ubuntu-standard
apt-get -y install lsof
apt-get -y install openssh-server

#Enable UFW
ufw allow from 192.168.1.0/24 to any port 22
ufw enable

#Webmin
echo "deb http://download.webmin.com/download/repository sarge contrib" | tee -a /etc/apt/sources.list
wget http://www.webmin.com/jcameron-key.asc
apt-key add jcameron-key.asc
apt-get update
apt-get -y install webmin
ufw allow from 192.168.1.0/24 to any port 10000

# remove myself to prevent any unintended changes at a later stage
rm $0

# finish
echo " DONE; rebooting ... "

# reboot
reboot
