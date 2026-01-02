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

cat > /var/lib/lxc/lxc-guest01/rootfs/etc/sysconfig/network-scripts/ifcfg-eth0 << "EOF"
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

IPADDR=192.168.122.11
NETMASK=255.255.255.0
GATEWAY=192.168.122.1
DNS1=8.8.8.8
EOF

```

```
lxc-ls -f
lxc-start -n lxc-guest01 -d
lxc-ls -f
lxc-attach -n lxc-guest01
```

config for LXC container.


```
# Create bridge interface (e.g., lxcbr0)
cat > /etc/sysconfig/network-scripts/ifcfg-brint01 << 'EOF'
DEVICE=brint01
TYPE=Bridge
BOOTPROTO=none
ONBOOT=yes
DELAY=0
NM_CONTROLLED=no
EOF

ifup brint01
ip addr show brint01
```

Create namespace.

```
# Create network namespace
ip netns add gateway-ns

# Create first veth pair for brint01
ip link add veth-gw type veth peer name veth-br
brctl addif brint01 veth-br
ip link set veth-br up
ip link set veth-gw netns gateway-ns
ip netns exec gateway-ns ip addr add 172.31.0.1/16 dev veth-gw
ip netns exec gateway-ns ip link set veth-gw up

# Create second veth pair for virbr0
ip link add veth-gw2 type veth peer name veth-vir
brctl addif virbr0 veth-vir
ip link set veth-vir up
ip link set veth-gw2 netns gateway-ns
ip netns exec gateway-ns ip addr add 192.168.122.254/24 dev veth-gw2
ip netns exec gateway-ns ip link set veth-gw2 up
```

Enter namespace and verify it.

```
ip netns exec gateway-ns sysctl -w net.ipv4.ip_forward=1
ip netns exec gateway-ns ip addr show
ip netns exec gateway-ns bash -c 'export PS1="(gateway-ns) [\u@\h \W]\$ "; exec bash'
ip netns identify $$
```


Enter the session of the namespace and configure NAT and routing.

```
ip netns exec gateway-ns bash
```

