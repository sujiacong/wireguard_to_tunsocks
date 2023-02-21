# wireguard_to_tunsocks

<h1>How To</h1>

<h2>1.Download Ubuntu 22.04 vmware image</h2>
download Ubuntu 22.04 vmware image,default user/pass is osboxes/osboxes.org
```bash
wget https://jaist.dl.sourceforge.net/project/osboxes/v/vm/55-U--u/22.04/64bit.7z --no-check-certificate`
```

<h2>2.Start Ubuntu 22.04</h2>
Create a new virtual machine, use the downloaded image as the hard disk.  

Start virtual machine and install basic software:  

```bash
apt install ssh lrzsz
```

Bridge the network with PC network, then use ip to add address,for example:  

```bash
ip addr add 192.168.3.100/24 via 192.168.3.1 dev ens33
```

Use ssh client connect to Ubuntu 22.04 and use rz to copy wireguard_to_tunsocks to host.  

<h2>3.deploy wireguard_to_tunsocks</h2>

Select Out Interface  

![Select Interface](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/1.png?raw=true)  

Set Wireguard IPv4 and Port  

![Wireguard Service](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/2.png?raw=true)  

Set Default Out GateWay  

![Out GateWay](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/3.png?raw=true)  

Set wireguard networks  

![Wireguard Network](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/4.png?raw=true)  

Set bypass networks  

![Bypass Network](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/5.png?raw=true)

Set Remote SSH Host:Port  

![alt text](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/6.png?raw=true)

Set Remote SSH User:Pass  

![Remote SSH Host/Port](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/7.png?raw=true)

Set wireguard networks max peers  

![Remote SSH User/Pass](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/8.png?raw=true)

Install Complete,use wireguard client scan QR code in /etc/wireguard/config/peerx/peerx.png!  

all log messages goes file /var/log/syslog!  

![Deploy Complete](https://github.com/sujiacong/wireguard_to_tunsocks/blob/main/blob/main/9.png?raw=true)


