#!/bin/bash

check_user()
{
   local user=`whoami`
   if [[ "$user" != "root" ]]
   then
       echo "please using root to install this patch"
       exit 1
   fi
}

cyan_echo()
{
    echo -e "$FMTCYAN""$@""$FMTEND"
}

green_echo()
{
    echo -e "$FMTGREEN""$@""$FMTEND"
}

red_error_echo()
{
    echo -e "$FMTRED""$@""$FMTEND"
}

is_valid_ipv4_format()
{
   if [ "x$1" = "x" ] || [ "x$2" = "x" ]
   then
       return 1
   fi
   if [ "x$2" != "x" ]
   then
       expr $2 + 0 >/dev/null 2>&1
       if [ $? -ne 0 ]
       then
           return 1
       fi
   fi
   if [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
   then
       if [ "x$2" != "x" ]
       then
           if [ $2 -le 32 ] && [ $2 -ge 0 ]
           then
                return 0
           fi
       else
           return 0
       fi
  fi
  return 1
}

timer_read()
{
   if [[ -z $1 || -z $2 ]]
   then
       return 1;
   fi
   local timer=$1;
   local var=$2;
   local default=$3;
   local start
   local end
   eval $var=""
   start=`date +%s`
   eval read -t $timer $var
   end=`date +%s`
   if [[ $[$end-$start] -ge $timer ]]
   then
       if [[ `eval echo "$"$var` = "" ]]
       then
           eval $var=$default
           echo "$default"
           return 0;
       fi
   fi
   return 0;
}

select_interface()
{
	local pinterfaces=($(ls -l /sys/class/net/ | egrep -v 'virtual|total' | awk '{print $NF}' | awk -F/ '{print $NF}'))
	local eth_nums=${#pinterfaces[@]}
 	local newpinterfaces=()	
	local name
	for name in ${pinterfaces[@]}
	do
	    newpinterfaces=(${newpinterfaces[*]} $name)
        done
	pinterfaces=(${newpinterfaces[*]})
	eth_nums=${#pinterfaces[@]}
        while true
        do
             eth_num=1
             cyan_echo "#########select internet network OUT interface,please input 1-$eth_nums ########"
             for eth in ${pinterfaces[@]}
             do     
                cyan_echo "$eth_num.    $eth"
                ((eth_num+=1))
             done
             cyan_echo "#############################################################################################"
             echo -n "Please select internet OUT interface,will automatic use the first choice in 120 seconds:"
             timer_read 120 select_num 1
	     if [ -z $select_num ]
	     then
		 continue
	     fi
             expr $select_num + 1 2>/dev/null 1>/dev/null
             if [ $? -ne 0 ]
             then
                 red_error_echo "bad input"
		 continue
	     fi
             if [ $select_num -ge 1 ] && [ $select_num -le $[$eth_nums] ]
             then
                 eth_num=$[$select_num-1]
                 ETH_OUT=${pinterfaces[$eth_num]}
                 break;
             else
                 red_error_echo "bad input"
             fi
        done
	green_echo "OUT:$ETH_OUT"

	sed -i "s/OUT_DEV=.*/OUT_DEV=$ETH_OUT/g" wireguard/helper/add_route.sh  
	sed -i "s/OUT_DEV=.*/OUT_DEV=$ETH_OUT/g" wireguard/helper/del_route.sh  
}

input_wireguard_server_address()
{
        while true
        do
            cyan_echo "Please input OUT ipv4 address and port[10.16.1.23:41994]:"
            read input
            if [ -z "${input}" ]; then
		continue
            fi
            local ip4tmpaddr=`echo $input |awk -F":" '{print $1}'`
            local ip4tmpport=`echo $input |awk -F":" '{print $2}'`
            if ! is_valid_ipv4_format $ip4tmpaddr 32
            then
                red_error_echo "invalid ipv4:port format"
		continue
            fi
	    if [ -z $ip4tmpport ]
	    then
                red_error_echo "invalid ipv4:port format"
		continue
	    fi
            ETH_OUT_ADDR=$ip4tmpaddr
	    expr $ip4tmpport+1 2>/dev/null 1>/dev/null
	    if [ $? -ne 0 ]
	    then
                red_error_echo "invalid port"
		continue
	    fi
	    ETH_OUT_PORT=$ip4tmpport
	    break;
       done
       green_echo "Endpoint:$ETH_OUT_ADDR:$ETH_OUT_PORT"
}

set_wireguard_and_bypass_network()
{
        while true
        do
            cyan_echo "Please input wireguard networks,empty input will use 10.13.13.0:"
            read input
            if [ -z "${input}" ]
            then
		WG_NETWORK=10.13.13
		break
            fi
            if ! is_valid_ipv4_format $input 24
	    then
                red_error_echo "invalid ipv4 network format"
		continue
            fi
	    if ! echo $input|grep -E "\.0$"
	    then
                red_error_echo "invalid ipv4 network format"
		continue
            fi
	    WG_NETWORK=$(echo $input|sed 's/\.0$//')
	    break;
	done
	sed -i "s/VPN_NET=.*/VPN_NET=${WG_NETWORK}.0\/24/g" wireguard/helper/add_route.sh
	sed -i "s/VPN_NET=.*/VPN_NET=${WG_NETWORK}.0\/24/g" wireguard/helper/del_route.sh

       echo > tun2socks/bypass_rules.conf
       networks_num=0
        while true
        do
            cyan_echo "Please input bypass networks[example: 10.16.1.23/24],empty input for complete:"
            read input
            if [ -z "${input}" ]
	    then
	        while true
	        do
			cyan_echo "complete networks? (y/n)[n]:"
			read input
			if [ "x$input" = "xy" ]
			then
			    break 2;
			else
			    continue 2
			fi
	        done
            fi
            ip4tmpaddr=`echo $input |awk -F"/" '{print $1}'`
            ip4tmpprefix=`echo $input |awk -F"/" '{print $2}'`
            if is_valid_ipv4_format $ip4tmpaddr $ip4tmpprefix
            then
		echo "${ip4tmpaddr}/${ip4tmpprefix}" >> tun2socks/bypass_rules.conf
		((++networks_num))
		echo "have $networks_num network now"
		continue
            else
                red_error_echo "invalid ipv4 format"
            fi
       done	
       for network in $NETWORKS
       do
	    echo $network >> tun2socks/bypass_rules.conf
       done
       green_echo "bypass networks"
       cat tun2socks/bypass_rules.conf
}

set_network_default_route()
{
    while true
    do
        cyan_echo "Please set default gateway(ipv4):"
        read input
        if [ "x$input" != "x" ]
        then
           DEFAULT_GW=$input
           is_valid_ipv4_format $input 32
           if [ $? -eq 0 ]
           then
               DEFAULT_GW=$input
               green_echo "default gw $DEFAULT_GW"
               break;
           else
               red_error_echo "Input error, only ipv4 is supported."
	       continue
           fi
        else
            red_error_echo "input default gateway"
        fi
   done
   green_echo "GATEWAY_IP:$DEFAULT_GW"
   sed -i "s/GATEWAY_IP=.*/GATEWAY_IP=$DEFAULT_GW/g" tun2socks/bin/tun2socks_ctl 
}

set_socks_proxy_address()
{
	local ip4tmpaddr
	local ip4tmpport
        while true
        do
            cyan_echo "Please set socks5 proxy address:[127.0.0.1:48501],empty input will use 127.0.0.1:48501"
            read input
            if [ -z "${input}" ]; then
                SOCKS_ADDR=127.0.0.1
                SOCKS_PORT=48501
                green_echo "SOCKS5:$input"
                while true
                do
                        cyan_echo "config ssh dynamic socks5 proxy? (y/n)[n]:"
                        read input
                        if [ "x$input" = "xy" ]
                        then
			    set_ssh_socks5_proxy
                        else
                            break 2
                        fi
                done
                break;
            fi
            ip4tmpaddr=`echo $input |awk -F":" '{print $1}'`
            ip4tmpport=`echo $input |awk -F":" '{print $2}'`
            if is_valid_ipv4_format $ip4tmpaddr 32
            then
                green_echo "SOCKS:$input"
                SOCKS_ADDR=$ip4tmpaddr
                SOCKS_PORT=$ip4tmpport
                break;
            else
                red_error_echo "invalid ipv4 format"
            fi
       done	
       sed -i "s/SOCKS_SERVER=.*/SOCKS_SERVER=$SOCKS_ADDR/g" tun2socks/bin/tun2socks_ctl	
       sed -i "s/SOCKS_PORT=.*/SOCKS_PORT=$SOCKS_PORT/g" tun2socks/bin/tun2socks_ctl	
}

set_ssh_socks5_proxy()
{
        while true
        do
            cyan_echo "Please input remote ssh host:port[10.16.1.23:22]:"
            read input
            if [ -z "${input}" ]; then
		continue
            fi
            SSH_HOST=`echo $input |awk -F":" '{print $1}'`
            SSH_PORT=`echo $input |awk -F":" '{print $2}'`
	    if [ -z $SSH_PORT ]
	    then
                red_error_echo "invalid ssh host:port"
		continue;
            fi
            if ! is_valid_ipv4_format $SSH_HOST 32
            then
                red_error_echo "invalid ssh host:port"
		continue;
            fi
	    expr $SSH_PORT+1 2>/dev/null 1>/dev/null
	    if [ $? -ne 0 ]
	    then
		red_error_echo "invalid ssh port"
		continue;
	    fi
	    break;
       done
       sed -i "s/^SSH_HOST_REMOTE_ADDR=.*/SSH_HOST_REMOTE_ADDR=$SSH_HOST/g" tun2socks/bin/tun2socks_ctl
       sed -i "s/^SSH_HOST_REEOTE_PORT=.*/SSH_HOST_REEOTE_PORT=$SSH_PORT/g" tun2socks/bin/tun2socks_ctl
       echo $SSH_HOST/32 >> tun2socks/bypass_rules.conf
       while true
        do
            cyan_echo "Please input ssh user:password:[root:test123]"
            read input
            if [ -z "${input}" ]; then
		continue
            fi
            SSH_USER=`echo $input |awk -F":" '{print $1}'`
            SSH_PASS=`echo $input |awk -F":" '{print $2}'`
	    break;
       done
       sed -i "s/^SSH_HOST_REMOTE_USER=.*/SSH_HOST_REMOTE_USER=$SSH_USER/g" tun2socks/bin/tun2socks_ctl	
       sed -i "s/^SSH_HOST_REMOTE_PASS=.*/SSH_HOST_REMOTE_PASS=$SSH_PASS/g" tun2socks/bin/tun2socks_ctl	
       sed -i "s/^USE_SSH_SOCKS5=.*/USE_SSH_SOCKS5=1/g" tun2socks/bin/tun2socks_ctl	
}


create_wireguard_conf()
{
	while true
	do
		cyan_echo "please input peer number:"
		read input
		if [ "x$input" = "x" ]
		then
		    continue
		fi
		expr $input+1 2>/dev/null 1>/dev/null
		if [ $? -ne 0 ]
		then
		    continue
		fi
		if [ $input -gt 254 ]
		then
		    continue
		fi
		PEER_NUM=$input
		break;
	done
	cd wireguard
	wg genkey | tee server_privatekey| wg pubkey > server_publickey
	cat << EOF > wg0.conf
[Interface]
Address = ${WG_NETWORK}.1/32
DNS = 8.8.8.8,8.8.4.4
PostUp = /etc/wireguard/helper/add_route.sh
PostDown = /etc/wireguard/helper/del_route.sh
ListenPort = ${ETH_OUT_PORT}
PrivateKey = $(cat server_privatekey)
EOF
	j=0
	for i in `seq 1 $PEER_NUM`
	do
	   ((j=i+1))
	   dir=config/peer${i}
	   [ -d $dir ] || mkdir -p $dir
           wg genkey | tee $dir/cprivatekey | wg pubkey > $dir/cpublickey
	   cat << EOF >> wg0.conf
[Peer]
PublicKey = $(cat $dir/cpublickey)
AllowedIPs = ${WG_NETWORK}.${j}/32
EOF
	   cat << EOF > $dir/wg-client-${i}.conf
[Interface]
Address = ${WG_NETWORK}.${j}
PrivateKey = $(cat $dir/cprivatekey)

[Peer]
PublicKey = $(cat server_publickey)
Endpoint = ${ETH_OUT_ADDR}:${ETH_OUT_PORT}
AllowedIPs = ${WG_NETWORK}.0/24,1.0.0.0/8,2.0.0.0/7,4.0.0.0/6,8.0.0.0/5,16.0.0.0/4,32.0.0.0/3,64.0.0.0/2,128.0.0.0/1
PersistentKeepalive = 15
EOF
	   qrencode -t png -o $dir/peer${i}.png -r $dir/wg-client-${i}.conf
	done
}

###########################################################################################################main start###############################################
check_user
RUNDIR=`dirname $0`;if [ "${RUNDIR:0:1}" != "/" ];then RUNDIR=`pwd`/$RUNDIR;fi
cd $RUNDIR

if cat /proc/cmdline | grep ttyS0 > /dev/null 2>&1
then
    TTYNAME=ttyS0
elif cat /proc/cmdline | grep ttyAMA0 > /dev/null 2>&1
then
    TTYNAME=ttyAMA0
else
    TTYNAME=tty1
fi

if [ "x$TTYNAME" != "xtty1" ]
then
    FMTGREEN=""
    FMTRED=""
    FMTCYAN=""
    FMTYELLOW=""
    FMTEND=""
else
    FMTGREEN="\033[32m"
    FMTRED="\033[31m"
    FMTCYAN="\033[36m"
    FMTYELLOW="\033[33m"
    FMTEND="\033[0m"
fi

apt list --installed > installed.txt
for debpkg in net-tools rsync ssh vim lrzsz expect wireguard qrencode
do
    cat installed.txt|grep -Eq "^$debpkg/" || apt install $debpkg -y
done

clear

select_interface

input_wireguard_server_address

set_network_default_route

set_wireguard_and_bypass_network

set_ssh_socks5_proxy

rm -rf wireguard/config/

create_wireguard_conf

cd $RUNDIR

/bin/rm -rf /etc/wireguard/config/

rsync -av wireguard/ /etc/wireguard/

rsync -av tun2socks/ /usr/local/tun2socks/

if [ -h /etc/resolv.conf ]
then
    /bin/rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
fi
ln -snf /usr/bin/resolvectl /usr/local/bin/resolvconf

sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -w "net.ipv4.ip_forward=1"

sed -i '/net.ipv4.conf.all.src_valid_mark/d' /etc/sysctl.conf
echo "net.ipv4.conf.all.src_valid_mark=1" >> /etc/sysctl.conf
sysctl -w "net.ipv4.conf.all.src_valid_mark=1"

systemctl enable wg-quick@wg0.service
systemctl stop wg-quick@wg0.service
sleep 3
echo "starting wg-quick@wg0.service.service ..."
systemctl start wg-quick@wg0.service
sleep 3
echo "starting wg-quick@wg0.service.service complete!"
wg
/bin/cp -f tun2socks.service /usr/lib/systemd/system/
systemctl enable tun2socks.service
echo "starting tun2socks.service ..."
sleep 3
systemctl start tun2socks.service
echo "start tun2socks.service complete!"
echo "use wireguard client scan QR code in /etc/wireguard/config/peerx/peerx.png!"
echo "all log messages goes file /var/log/syslog!"

