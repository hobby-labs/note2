# Network Isolated LXC Container
Install LXC on CentOS7.9 host and create a network isolated container.
We need install update OpenSSH to support newer encryption algorithms and avoid vulnerabilities.

```
yum install -y gcc make perl-core zlib-devel

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

# Now configure OpenSSH with the new OpenSSL
cd /usr/local/src/openssh-9.9p1
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-pam --with-zlib \
    --with-ssl-dir=/usr/local/openssl --with-openssl=/usr/local/openssl
make
make install

systemctl restart sshd
```

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
```

Configure network bridge for LXC containers.

```
# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Create default bridge network
cat > /etc/sysconfig/network-scripts/ifcfg-lxcbr0 << EOF
DEVICE=lxcbr0
TYPE=Bridge
BOOTPROTO=static
IPADDR=192.168.123.1
NETMASK=255.255.255.0
ONBOOT=yes
DELAY=0
EOF

systemctl restart network
```

After restarting the network service, verify the bridge configuration.

```
# ip address show lxcbr0
3: lxcbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether ea:cd:20:dd:99:9d brd ff:ff:ff:ff:ff:ff
    inet 192.168.123.1/24 brd 192.168.123.255 scope global noprefixroute lxcbr0
       valid_lft forever preferred_lft forever
```

```
template-machine ~# tar --numeric-owner --exclude=/proc --exclude=/sys --exclude=/dev \
                        --exclude=/run --exclude=/tmp --exclude=/mnt --exclude=/media \
                        -czf /tmp/centos7-rootfs.tar.gz /
```

```
mkdir -p /var/lib/lxc/mycontainer/rootfs/
mv /tmp/centos7-rootfs.tar.gz /var/lib/lxc/mycontainer/rootfs/
cd /var/lib/lxc/mycontainer/rootfs/
tar xzf centos7-rootfs.tar.gz --strip-components=1

mkdir -p /var/lib/lxc/mycontainer/rootfs/{proc,sys,dev,run,tmp}
cat > /var/lib/lxc/mycontainer/config << 'EOF'
lxc.utsname = mycontainer
lxc.rootfs = /var/lib/lxc/mycontainer/rootfs
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = lxcbr0
lxc.network.name = eth0
EOF
```

```
lxc-ls -f
lxc-start -n mycontainer -d

```
