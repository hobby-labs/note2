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

# Network Isolated LXC Container

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
mkdir -p /var/lib/lxc/mycontainer/rootfs/
mv ./centos7-rootfs.tar.xz /var/lib/lxc/mycontainer/rootfs/
cd /var/lib/lxc/mycontainer/rootfs/
tar -Jxf centos7-rootfs.tar.xz

mkdir -p /var/lib/lxc/mycontainer/rootfs/{proc,sys,dev,run,tmp}
cat > /var/lib/lxc/mycontainer/config << 'EOF'
lxc.utsname = mycontainer
lxc.rootfs = /var/lib/lxc/mycontainer/rootfs
lxc.network.type = veth
lxc.network.flags = up
lxc.network.link = virbr0
lxc.network.name = eth0
EOF
```

```
lxc-ls -f
lxc-start -n mycontainer -d

```
