#!/bin/bash

getParam()
{
   echo $1|awk -F"=" '{print $2}'
}

usage()
{
   echo "usage example: $0 serverip=1.1.1.1 sshport=22 localport=443 user=root pass=123 key=/root/rassis_rsa"
   exit 0
}

if [[ $# -eq 0 ]]
then
    usage
fi

while [[ $# -ge 1 ]]
do
    arg=$1
    if echo $arg |grep -q "serverip="
    then
        serverip=`getParam $arg`
        echo "serverip  $serverip"
    elif echo $arg |grep -q "sshport="
    then
        sshport=`getParam $arg`
        echo "sshport $sshport"
    elif echo $arg |grep -q "localport="
    then
        localport=`getParam $arg`
        echo "localport $localport"
    elif echo $arg |grep -q "user="
    then
        user=`getParam $arg`
        echo "user $user"
    elif echo $arg |grep -q "pass="
    then
        pass=`getParam $arg`
        echo "pass $pass"
    elif echo $arg |grep -q "key="
    then
        key=`getParam $arg`
        echo "key $key"
    fi
    shift
done

if [[ -z $serverip ]]
then
    echo "missing serverip"
    exit 1
fi

if [[ -z $serverport ]]
then
    echo "missing serverport"
    exit 1
fi

if [[ -z $sshport ]]
then
    sshport=22
fi

if [[ -z $localport ]]
then
   localport=12345
fi

if [[ -z $user ]]
then
    user=root
fi

if [[ -z $pass ]]
then
    pass=111111
fi

if [[ -n $key ]]
then
    if [[ -f $key ]]
    then
        keyfile=$key
        chmod 600 $keyfile
    fi
fi

sshflags="-o ServerAliveInterval=15 -o ServerAliveCountMax=10 -o ConnectTimeout=60 -o ExitOnForwardFailure=yes";
sshcommand=/usr/bin/ssh

while true
do
    /bin/rm -f ~/.ssh/known_hosts
    if [[ -n $keyfile ]] 
    then
        expect -c "
        set timeout 1200;
        spawn $sshcommand -C -i $keyfile -p $sshport -N -q -D 0.0.0.0:$localport $user@$serverip $sshflags;
        expect {
        \"*yes/no*\" {send \"yes\r\"; exp_continue}
        \"*password*\" {send \"$pass\r\"; exp_continue}
        }
        expect eof;"
    else
        expect -c "
        set timeout 1200;
        spawn $sshcommand -C -p $sshport -N -q -D 0.0.0.0:$localport $user@$serverip $sshflags
        expect {
        \"*yes/no*\" {send \"yes\r\"; exp_continue}
        \"*password*\" {send \"$pass\r\"; exp_continue}
        }
        expect eof;"
    fi
    sleep 10
done


