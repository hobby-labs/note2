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
* [iPXE ブート環境をセットアップする](https://qiita.com/Yuhkih/items/c7cc9978ee107784c97f)

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
```

```
pxe-server src# make bin/ipxe.pxe bin/undionly.kpxe bin/undionly.kkpxe bin/undionly.kkkpxe bin-x86_64-efi/ipxe.efi
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
interface=enp1s0
bind-interfaces
domain=linuxhint.local

# * Option 2
# If you want to use another DHCP server that has been already running in your network,
# you should set dnamasq as proxy mode by setting "dhcp-range=x.x.x.x,proxy (x.x.x.x is a IP of pxe-server)".
# Or you can specify these parameters as arguments when running dnsmasq.
dhcp-range=172.31.0.99,proxy

# gPXE/iPXE sends a 175 option.
dhcp-match=set:ipxe,175

enable-tftp
tftp-root=/pxeboot

# A variable "next-server" will be passed.
# If you want to specify a value of it, you can put its value(y.y.y.y) like below.
pxe-service=x86PC,"splash"

# boot config for UEFI systems
# Set a tag "efi-x86_64" when client-arch(Option: 93) is 7(EFI BC) or 9(EFI x86-64).
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-boot=tag:efi-x86_64,tag:!ipxe,firmware/ipxe.efi,172.31.0.99
dhcp-boot=tag:efi-x86_64,tag:ipxe,http://172.31.0.99/os/config/boot.ipxe,172.31.0.99
EOF
```

```
pxe-server ~# dnsmasq
pxe-server ~# # or
pxe-server ~# systemctl restart dnsmasq
```

* /pxeboot/config/boot.ipxe
```
pxe-server ~# mkdir -p /var/www/os/config/
pxe-server ~# cat << 'EOF' > /var/www/os/config/boot.ipxe
#!ipxe
set root_path /pxeboot
set mac_addr ${net0/mac}
menu Select an OS to boot
item --gap --           -------------------- Choose installations --------------------
item ubuntu-22.04.3-live-server-amd64         Install Ubuntu 22.04 LTS (MAC: ${mac_addr})
item ubuntu-22.04.3-live-server-amd64-common  Install Ubuntu 22.04 LTS
item --gap --           ---------------------- Advanced options ----------------------
item --key c config     Configure settings
item shell              Drop to iPXE shell
item reboot             Reboot Computer
choose --default exit --timeout 180000 option && goto ${option}

:ubuntu-22.04.3-live-server-amd64
set os_root os/images/ubuntu-22.04.3-live-server-amd64
kernel http://${next-server}/${os_root}/casper/vmlinuz
initrd http://${next-server}/${os_root}/casper/initrd
imgargs vmlinuz initrd=initrd autoinstall ip=dhcp url=http://${next-server}/os/images/ubuntu-22.04.3-live-server-amd64.iso ds=nocloud-net;s=http://${next-server}/os/autoinstall/${mac_addr}/ ---
boot

:ubuntu-22.04.3-live-server-amd64-common
set os_root os/images/ubuntu-22.04.3-live-server-amd64
kernel http://${next-server}/${os_root}/casper/vmlinuz
initrd http://${next-server}/${os_root}/casper/initrd
imgargs vmlinuz initrd=initrd autoinstall ip=dhcp url=http://${next-server}/os/images/ubuntu-22.04.3-live-server-amd64.iso ds=nocloud-net;s=http://${next-server}/os/autoinstall/common/ ---
boot

:exit
exit

:cancel
echo You cancelled the menu, dropping you to a shell

:shell
echo Type 'exit' to get the back to the menu
shell
set menu-timeout 0
goto start

:reboot
reboot
EOF
```

```
pxe-server ~# mkdir -p /var/www/os/autoinstall/52:54:ff:00:00:01
pxe-server ~# cat << 'EOF' > /var/www/os/autoinstall/52:54:ff:00:00:01/user-data
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: ubuntu-server
    username: ubuntu
    # p@ssw0rd
    password: "$6$xyz$rfUoxhnScmjOykLAVIhgfxmKgIWmTirRSrIZ9j5EJ1Vf765rQS.dCbXjXBx4PuhbcNNrXx2XpwUywQ96C7EJB/"
  ssh:
    install-server: yes
EOF

pxe-server ~# mkdir -p /var/www/os/autoinstall/common
pxe-server ~# cat << 'EOF' > /var/www/os/autoinstall/common/user-data
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: common
    username: ubuntu
    # p@ssw0rd
    password: "$6$xyz$rfUoxhnScmjOykLAVIhgfxmKgIWmTirRSrIZ9j5EJ1Vf765rQS.dCbXjXBx4PuhbcNNrXx2XpwUywQ96C7EJB/"
  ssh:
    install-server: yes
EOF

pxe-server ~# touch /var/www/os/autoinstall/52:54:ff:00:00:01/meta-data
pxe-server ~# touch /var/www/os/autoinstall/common/meta-data
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
    # /os/autoinstall: A location storing cloud-init configurations
    # /os/config:      iPXE scripts to boot it.
    # /os/images:      OS images
    location /os {
        root /var/www/;
        autoindex on;
    }
}
EOF

pxe-server ~# systemctl restart nginx
```

## OS image

```
pxe-server ~# wget https://releases.ubuntu.com/jammy/ubuntu-22.04.3-live-server-amd64.iso
pxe-server ~# mount -o loop ubuntu-22.04.3-live-server-amd64.iso /mnt
pxe-server ~# mkdir -p /var/www/os/images/ubuntu-22.04.3-live-server-amd64

pxe-server ~# rsync -avz /mnt/casper/* /var/www/os/images/ubuntu-22.04.3-live-server-amd64/casper/
pxe-server ~# umount /mnt
pxe-server ~# mv ubuntu-22.04.3-live-server-amd64.iso /var/www/os/images/
```

## Test instlling OS from the PXE server
Test it by running KVM instance in same network with the PXE server.

```
some-kvm-host ~# mkdir -p /var/kvm/distros/ubuntu-server-22.04/
some-kvm-host ~# virt-install --pxe \
                     --boot uefi \
                     --name ubuntu-server-22.04 \
                     --connect=qemu:///system \
                     --vcpus=2 \
                     --memory 16384 \
                     --disk path=/var/kvm/distros/ubuntu-server-22.04/disk.img,size=16,format=qcow2 \
                     --os-variant=ubuntu22.04 \
                     --arch x86_64 \
                     --network bridge:br0,mac=52:54:ff:00:00:01 \
                     --graphics vnc,port=15901,listen=127.0.0.1
```

