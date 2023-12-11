This is an instruction to ...

* Provide boot firmware(iPXE) with tftp
* Provide images of casper boot with http
* Provide images of OS with http
* Specify IP address in some scripts dynamically with a variable next-server.

# Creating iPXE server with docker container
* [Configuring PXE Network Boot Server on Ubuntu 22.04 LTS](https://linuxhint.com/pxe_boot_ubuntu_server/)
* [PXEでサーバーの完全自動インストールを行う](https://gihyo.jp/admin/serial/01/ubuntu-recipe/0787)
* [chaperone/dnsmasq](https://web.chaperone.jp/w/index.php?dnsmasq#dd0961a7)
* [Chainloading iPXE](https://ipxe.org/howto/chainloading)
* [既存のDHCPサーバが存在する場合でもPXE Bootをする（dnsmasqを使ったProxy DHCPの設定）](https://zappy.hatenablog.jp/entry/2018/05/31/190434)

```
pxe-server ~# docker network create -d macvlan \
    --subnet=172.31.0.0/16 \
    --gateway=172.31.0.1 \
    -o parent=br0 home_network

pxe-server ~# docker network ls
NETWORK ID     NAME                                                          DRIVER    SCOPE
...
7021324f4636   home_network                                                  macvlan   local
...

pxe-server ~# docker run --rm --name test-ipxe-server --hostname test-ipxe-server \
    --network home_network --ip 172.31.0.99 --dns 172.31.0.1 \
    -ti ubuntu:22.04 bash
```

```
pxe-server ~# mkdir -p /pxeboot/{config,firmware,os-images}
```

```
pxe-server ~# apt-get update
pxe-server ~# apt-get install -y build-essential liblzma-dev isolinux git iproute2
```

```
pxe-server ~# cd ~
pxe-server ~# git clone https://github.com/ipxe/ipxe.git
pxe-server ~# # A commit 98dd25a is the latest when I was using it.
pxe-server ~# git -C ipxe checkout -b 98dd25a3bb2d3aafa71f088cbabf89418a783132 98dd25a3bb2d3aafa71f088cbabf89418a783132
pxe-server ~# cd ipxe/src
pxe-server src# cat << 'EOF' > bootconfig.ipxe
#!ipxe
dhcp
chain http://172.31.0.99/config/boot.ipxe
EOF
```

```
pxe-server src# make bin/ipxe.pxe bin/undionly.kpxe bin/undionly.kkpxe bin/undionly.kkkpxe bin-x86_64-efi/ipxe.efi EMBED=bootconfig.ipxe
...
pxe-server src# cp -v bin/{ipxe.pxe,undionly.kpxe,undionly.kkpxe,undionly.kkkpxe} bin-x86_64-efi/ipxe.efi /pxeboot/firmware/
pxe-server src# cd ~
```

## Disable systemd-resolved is using port 53 (optional)

```
pxe-server ~# cp -a /etc/systemd/resolved.conf /etc/systemd/resolved.conf.org
pxe-server ~# sed -i -e "s/^#DNS=.*/DNS=172.31.0.1/g"                 /etc/systemd/resolved.conf
pxe-server ~# sed -i -e "s/^#FallbackDNS=.*/FallbackDNS=8.8.8.8/g"    /etc/systemd/resolved.conf
pxe-server ~# sed -i -e "s/^#DNSStubListener=.*/DNSStubListener=no/g" /etc/systemd/resolved.conf
pxe-server ~# ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

pxe-server ~# systemctl restart systemd-resolved.service
```

## dnsmasq

```
pxe-server ~# apt-get install -y dnsmasq
pxe-server ~# mv -v /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
```

```
pxe-server ~# cat << 'EOF' > /etc/dnsmasq.conf
# You can change a name of interface depends on your environment.
interface=eth0
bind-interfaces
domain=linuxhint.local
## # * Option 1
## # If you want to use dnsmasq as a stand alone DHCP server,
## # you should set "dhcp-range", "dhcp-option=option:router", "dhcp-option=option:dns-server".
## # Or you can specify these parameters as arguments when running dnsmasq.
##dhcp-range=172.31.0.201,172.31.0.250,255.255.0.0
##dhcp-option=option:router,172.31.0.1
##dhcp-option=option:dns-server,1.1.1.1
##dhcp-option=option:dns-server,8.8.8.8

# * Option 2
# If you want to use another DHCP server that has been already running in your network,
# you should set dnamasq as proxy mode by setting "dhcp-range=x.x.x.x,proxy (x.x.x.x is a IP of pxe-server)".
# Or you can specify these parameters as arguments when running dnsmasq.
dhcp-range=172.31.0.99,proxy

enable-tftp
tftp-root=/pxeboot

# boot config for BIOS systems
dhcp-match=set:bios-x86,option:client-arch,0
dhcp-boot=tag:bios-x86,firmware/ipxe.pxe,172.31.0.99

# A variable "next-server" will be passed.
# If you want to specify a value of it, you can put its value(y.y.y.y) like below.
## pxe-service=tag:!ipxe,x86PC,"splash",firmware/undionly.kpxe,y.y.y.y
# Or the value you specified at "dhcp-range" will be passed as a variable "next-server".
pxe-service=tag:!ipxe,x86PC,"splash",firmware/undionly.kpxe

# boot config for UEFI systems
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-boot=tag:efi-x86_64,firmware/ipxe.efi
EOF
```

```
pxe-server ~# dnsmasq
pxe-server ~# # or
pxe-server ~# systemctl restart systemd-resolved.service
```

* /pxeboot/config/boot.ipxe
```
pxe-server ~# mkdir -p /var/www/config/
pxe-server ~# cat << 'EOF' > /var/www/config/boot.ipxe
#!ipxe
set server_ip ${next-server}
set root_path /pxeboot
menu Select an OS to boot
item ubuntu-22.04-desktop-amd64         Install Ubuntu Desktop 22.04 LTS
choose --default exit --timeout 60000 option && goto ${option}

:ubuntu-22.04-desktop-amd64
set os_root os-images//ubuntu-22.04.3-desktop-amd64
kernel http://${server_ip}/${os_root}/casper/vmlinuz
initrd http://${server_ip}/${os_root}/casper/initrd
imgargs vmlinuz initrd=initrd autoinstall ip=dhcp url=http://172.31.0.99/os-images/ubuntu-22.04.3-desktop-amd64.iso ds=nocloud-net;s=http://172.31.0.99/autoinstall/default/ ---
boot
EOF
```

## http

```
pxe-server ~# apt-get install -y nginx
pxe-server ~# cp -a /etc/nginx/sites-available/default /etc/nginx/sites-available/default.org
pxe-server ~# cat << 'EOF' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;

    index index.html index.htm index.nginx-debian.html;
    server_name _;

    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        try_files $uri $uri/ =404;
    }
    location /autoinstall {
        root /var/www/;
        autoindex on;
    }
    location /config {
        root /var/www/;
        autoindex on;
    }
    location /os-images {
        root /var/www/;
        autoindex on;
    }
}
EOF

pxe-server ~# systemctl restart nginx
```

## OS image

```
pxe-server ~# wget https://releases.ubuntu.com/jammy/ubuntu-22.04.3-desktop-amd64.iso
pxe-server ~# mount -o loop ubuntu-22.04.3-desktop-amd64.iso /mnt
pxe-server ~# mkdir -p /var/www/os-images/ubuntu-22.04.3-desktop-amd64
pxe-server ~# rsync -avz /mnt/casper/* /var/www/os-images/ubuntu-22.04.3-desktop-amd64/casper/
pxe-server ~# umount /mnt
pxe-server ~# mv ubuntu-22.04.3-desktop-amd64.iso /var/www/os-images/
```

## Test instlling OS from the PXE server
Test it by running KVM instance in same network with the PXE server.

```
some-kvm-host ~# mkdir -p /var/kvm/distros/ubuntu-desktop-22.04/
some-kvm-host ~# virt-install \
                     --pxe \
                     --boot uefi \
                     --name ubuntu-desktop-22.04 \
                     --connect=qemu:///system \
                     --vcpus=2 \
                     --memory 4096 \
                     --disk path=/var/kvm/distros/ubuntu-desktop-22.04/disk.img,size=16,format=qcow2 \
                     --os-variant=ubuntu22.04 \
                     --arch x86_64 \
                     --network bridge:br0 \
                     --graphics vnc,port=15901,listen=127.0.0.1
```

