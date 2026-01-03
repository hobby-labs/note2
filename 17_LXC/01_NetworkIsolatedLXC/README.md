# Before You Start
This instruction will use a CentOS7.9 host to create a network isolated LXC container.
Before you start, you should use alternative repository mirrors to avoid errors during package installation.
Current CentOS7.9 default repository is not available anymore.

Create a backup of existing repo files and create a new repo file pointing to CentOS vault.

```
# Backup existing repo files
cd /etc/yum.repos.d/
mkdir backup
mv *.repo backup/

# Create new repo file pointing to vault
cat > /etc/yum.repos.d/CentOS-Base.repo << 'EOF'
[base]
name=CentOS-$releasever - Base
baseurl=http://vault.centos.org/7.9.2009/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-$releasever - Updates
baseurl=http://vault.centos.org/7.9.2009/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-$releasever - Extras
baseurl=http://vault.centos.org/7.9.2009/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[centosplus]
name=CentOS-$releasever - Plus
baseurl=http://vault.centos.org/7.9.2009/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
```

Clean cache and test.

```
yum clean all
yum makecache
yum update -y
```

## OpenSSL and OpenSSH Update
Install LXC on CentOS7.9 host and create a network isolated container.
We need install update OpenSSH to support newer encryption algorithms and avoid vulnerabilities.
And OpenSSH needs to be compiled with a newer OpenSSL version (1.1.1 or above).

```
yum install -y gcc make perl-core zlib-devel wget vim pam-devel

# Download and compile OpenSSL 1.1.1
cd /usr/local/src
wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz
tar xzf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w

# Configure to install in /usr/local to avoid breaking system
./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
make
make install

# Add to library path
echo "/usr/local/openssl/lib" > /etc/ld.so.conf.d/openssl-1.1.1.conf
ldconfig

rm -rf /usr/local/src/{openssl-1.1.1w.tar.gz,openssl-1.1.1w}
```

Install and configure OpenSSH with the new OpenSSL.

```
cd /usr/local/src/
wget https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.9p1.tar.gz
tar xzf openssh-9.9p1.tar.gz
cd openssh-9.9p1
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-pam --with-zlib \
    --with-ssl-dir=/usr/local/openssl --with-openssl=/usr/local/openssl
make
make install

# Fix permissions for host keys
chmod 600 /etc/ssh/ssh_host_rsa_key
chmod 600 /etc/ssh/ssh_host_ecdsa_key
chmod 600 /etc/ssh/ssh_host_ed25519_key

# Also fix public key permissions (should be 644)
chmod 644 /etc/ssh/ssh_host_rsa_key.pub
chmod 644 /etc/ssh/ssh_host_ecdsa_key.pub
chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^GSSAPIAuthentication/#GSSAPIAuthentication/' /etc/ssh/sshd_config
sed -i 's/^GSSAPICleanupCredentials/#GSSAPICleanupCredentials/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication\s\+.*/PasswordAuthentication no/' /etc/ssh/sshd_config

rm -rf /usr/local/src/{openssh-9.9p1,openssh-9.9p1.tar.gz}

systemctl restart sshd
```

## Change hostname
```
echo "lxc-host" > /etc/hostname
```

## Change locale
```
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/UTC /etc/localtime
```

// A snapshot name "updated"

## LXC Installation and Configuration

```
# Install EPEL repository
yum install -y epel-release

# Update repository cache
yum clean all
yum makecache

# Install LXC and related tools
yum install -y lxc lxc-templates lxc-extra libvirt

# Start and enable lxc services
systemctl start lxc.service
systemctl enable lxc.service

# Verify installation
lxc-checkconfig

# Check version
lxc-info --version

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Restart OS for applying all changes
shutdown -r now
```

After re-starting the OS, check whether the bridge network is created.

```
ip a
> ...
> 3: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
>     link/ether 52:54:00:b0:3c:af brd ff:ff:ff:ff:ff:ff
>     inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
>        valid_lft forever preferred_lft forever
> ...
```

```
XZ_OPT='-9 -T0' tar -C / --numeric-owner --exclude=./proc --exclude=./sys --exclude=./dev \
    --exclude=./run --exclude=./tmp --exclude=./mnt --exclude=./media \
    -Jcf centos7-rootfs.tar.xz .
```

Download a CentOS7 rootfs tarball from a trusted source or create your own as shown above.

```
mkdir -p /var/lib/lxc/lxc-guest01/rootfs/
mv ./centos7-rootfs.tar.xz /var/lib/lxc/lxc-guest01/rootfs/
cd /var/lib/lxc/lxc-guest01/rootfs/
tar -Jxf centos7-rootfs.tar.xz

mkdir -p /var/lib/lxc/lxc-guest01/rootfs/{proc,sys,dev,run,tmp}
cat > /var/lib/lxc/lxc-guest01/config << 'EOF'
lxc.utsname = lxc-guest01
lxc.rootfs = /var/lib/lxc/lxc-guest01/rootfs
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = virbr0
lxc.network.name = eth0

lxc.aa_profile = unconfined
lxc.cgroup.devices.allow = a
lxc.cap.drop =
EOF

echo "lxc-guest01" > /var/lib/lxc/lxc-guest01/rootfs/etc/hostname

# Inside the container
cp /var/lib/lxc/lxc-guest01/rootfs/etc/fstab /var/lib/lxc/lxc-guest01/rootfs/etc/fstab.backup

cat > /var/lib/lxc/lxc-guest01/rootfs/etc/fstab << 'EOF'
# LXC container - minimal fstab
# Root filesystem is managed by LXC
tmpfs   /dev/shm   tmpfs   defaults   0 0
devpts  /dev/pts   devpts  gid=5,mode=620  0 0
sysfs   /sys       sysfs   defaults   0 0
proc    /proc      proc    defaults   0 0
EOF


```

-----------------------
Creating bridges.

```
./create_bridge.sh --bridge-name ns01-br00
./create_bridge.sh --bridge-name ns01-br01
./create_bridge.sh --bridge-name ns02-br00
./create_bridge.sh --bridge-name ns02-br01
```

ip netns identify $$

------------------------------------------------------------------------------------------

* Creating ns01
```
./create_ns.sh --name ns01 \
    --outer-link-name link-ns01-vb0 --outer-interface veth-ns01-vb0 --outer-peer-bridge virbr0 --outer-ip-with-cidr 192.168.122.254/24 \
    --inner-link-name link-ns01-br00 --inner-interface veth-ns01-br00 --inner-peer-bridge ns01-br00 --inner-ip-with-cidr 172.31.0.1/16 \
    --default-gateway 192.168.122.1

./create_ns.sh --name ns02 \
    --outer-link-name link-ns02-vb0 --outer-interface veth-ns02-vb0 --outer-peer-bridge virbr0 --outer-ip-with-cidr 192.168.122.253/24 \
    --inner-link-name link-ns02-br00 --inner-interface veth-ns02-br00 --inner-peer-bridge ns02-br00 --inner-ip-with-cidr 172.31.0.1/16 \
    --default-gateway 192.168.122.1

```

Enter namespace.

```
nsname=ns01
ip netns exec ${nsname} bash -c "
export NSNAME=${nsname}
export PS1=\"(${nsname})[\u@\h \W]\$ \"
mkdir -p /var/lib/lxc-ns/${nsname}
export LXC_BASE_DIR=/var/lib/lxc-ns
export LXCPATH=${LXC_BASE_DIR}/${nsname}
exec bash
"
```

------------------------------------------------------------------------------------------

```
lxc_name=lxc-guest01
outer_bridge_name=virbr0
inner_bridge_name=ns01-br00

mkdir -p /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/
mv ~/centos7-rootfs.tar.xz /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/
tar -C /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/ -Jxf centos7-rootfs.tar.xz
mkdir -p /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/{proc,sys,dev,run,tmp}

./create_lxc_config.sh \
    --lxc-base-dir /var/lib/lxc-ns --lxc-name ${lxc_name} --ns-name ${NSNAME} \
    --interface "link=${outer_bridge_name},name=eth0" \
    --interface "link=${inner_bridge_name},name=eth1"



cat > /var/lib/lxc-ns/${NSNAME}/${lxc_name}/config << EOF
lxc.utsname = ${lxc_name}
lxc.rootfs = /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs

# First network interface (eth0) - connected to ns01-br00
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = ${outer_bridge_name}
lxc.network.name = eth0

# Second network interface (eth1) - connected to ns01-br01
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = ${inner_bridge_name}
lxc.network.name = eth1

lxc.aa_profile = unconfined
lxc.cgroup.devices.allow = a
lxc.cap.drop =
EOF

echo "${lxc_name}" > /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/etc/hostname
# Inside the container
cp /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/etc/fstab /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/etc/fstab.backup

cat > /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/etc/fstab << 'EOF'
# LXC container - minimal fstab
# Root filesystem is managed by LXC
tmpfs   /dev/shm   tmpfs   defaults   0 0
devpts  /dev/pts   devpts  gid=5,mode=620  0 0
sysfs   /sys       sysfs   defaults   0 0
proc    /proc      proc    defaults   0 0
EOF

./set_interface_of_container.sh \
    --lxc-base-dir /var/lib/lxc-ns --lxc-name ${lxc_name} --ns-name ${NSNAME} \
    --interface-name eth0 --ip-address-with-cidr 192.168.122.254 --netmask 255.255.255.0 --gateway 192.168.122.1 --dns 8.8.8.8

cat > /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/etc/sysconfig/network-scripts/ifcfg-eth0 << "EOF"
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth0
UUID=ba020b0a-8c3a-4c40-b591-ab17b165bb88
DEVICE=eth0
ONBOOT=yes

IPADDR=192.168.122.254
NETMASK=255.255.255.0
GATEWAY=192.168.122.1
DNS1=8.8.8.8
EOF

cat > /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/etc/sysconfig/network-scripts/ifcfg-eth1 << "EOF"
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth1
UUID=ba020b0a-8c3a-4c40-b591-ab17b165bb89
DEVICE=eth1
ONBOOT=yes

IPADDR=172.31.0.1
NETMASK=255.255.0.0
EOF


iptables -t nat -A POSTROUTING -o veth-gw2 -j MASQUERADE
# or
# iptables -t nat -D POSTROUTING -s 172.31.0.0/16 -o veth-gw2 -j SNAT --to-source 192.168.122.254
# If you want to delete NAT rules
# iptables -t nat -F

```


