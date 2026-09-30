# 

```
$ osinfo-query os | grep -i alpine
......
 alpinelinux3.22      | Alpine Linux 3.22                                  | 3.22     | http://alpinelinux.org/alpinelinux/3.22
 alpinelinux3.23      | Alpine Linux 3.23                                  | 3.23     | http://alpinelinux.org/alpinelinux/3.23
 alpinelinux3.24      | Alpine Linux 3.24                                  | 3.24     | http://alpinelinux.org/alpinelinux/3.24
......
```

```
ALPINE_VER=3.24.2   # replace with the current release
cd /var/kvm/iso
wget https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER%.*}/releases/x86_64/alpine-virt-${ALPINE_VER}-x86_64.iso
```

```
$ name=alpine
$ mkdir /var/kvm/distros/${name%.*}
$ virt-install \
    --name ${name} \
    --memory 512 \
    --vcpus 1 \
    --boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no \
    --cdrom /var/kvm/iso/alpine-virt-${ALPINE_VER}-x86_64.iso \
    --disk path=/var/kvm/distros/${name%.*}/disk.qcow2,size=30,format=qcow2,bus=virtio \
    --os-variant alpinelinux"${ALPINE_VER%.*}" \
    --network bridge:br0 \
    --graphics none \
    --console pty,target_type=serial
```

```
Welcome to Alpine Linux 3.24
Kernel 6.18.52-0-virt on x86_64 (/dev/ttyS0)

localhost login: root
Welcome to Alpine!

...
```



```
$ echo "alpine" > /etc/hostname
$ hostname -F /etc/hostname
```

```
cat << 'EOF' > /etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 172.31.20.231/16
    gateway 172.31.0.1
EOF
```


```
$ cat > /etc/resolv.conf <<'EOF'
nameserver 172.31.0.1
EOF
```

```
$ rc-service networking restart
$ rc-update add networking boot
```

```
# read version < /etc/alpine-release
rc-update add networking boot
# echo $version
> 3.24.2
# echo ${version%.*}
> 3.24

# cat > /etc/apk/repositories << EOF
https://ftp.yz.yamagata-u.ac.jp/pub/linux/alpine/v${version%.*}/main
https://ftp.yz.yamagata-u.ac.jp/pub/linux/alpine/v${version%.*}/community
EOF

# apk update
```


```
# setup-disk -m sys /dev/vda

WARNING: The following disk(s) will be erased:
  vda	(32.2 GB 0x1af4 )

WARNING: Erase the above disk(s) and continue? (y/n) [n] y
...
```


```
$ sudo virsh domblklist alpine3
>  Target   Source
> -----------------------------------------------
>  vda      /var/kvm/distros/alpine3/disk.qcow2
>  sda      -

$ sudo virsh change-media alpine3 sda --eject
> error: The disk device 'sda' doesn't have media

$ sudo virsh start alpine3 --console
```



