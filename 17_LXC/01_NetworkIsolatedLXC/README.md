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
yum clean all
cd /tmp
XZ_OPT='-9 -T0' tar -C / --numeric-owner --exclude=./proc --exclude=./sys --exclude=./dev \
    --exclude=./run --exclude=./tmp --exclude=./mnt --exclude=./media \
    -Jcf centos7-rootfs.tar.xz .
```

Download a CentOS7 rootfs tarball from a trusted source or create your own as shown above.

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
export PS1=\"(\${NSNAME})[\u@\h \W]\$ \"
mkdir -p /var/lib/lxc-ns/\${NSNAME}
export LXC_BASE_DIR=/var/lib/lxc-ns
export LXCPATH=\${LXC_BASE_DIR}/\${NSNAME}

# Create aliases for lxc commands to automatically use -P flag
alias lxc-ls='lxc-ls -P \${LXCPATH}'
alias lxc-start='lxc-start -P \${LXCPATH}'
alias lxc-stop='lxc-stop -P \${LXCPATH}'
alias lxc-info='lxc-info -P \${LXCPATH}'
alias lxc-attach='lxc-attach -P \${LXCPATH}'
alias lxc-console='lxc-console -P \${LXCPATH}'
alias lxc-destroy='lxc-destroy -P \${LXCPATH}'

exec bash
"
```

------------------------------------------------------------------------------------------

```
lxc_name=lxc-guest01
outer_bridge_name=virbr0
outer_interface_name=eth0
inner_bridge_name=ns01-br00
inner_interface_name=eth1

mkdir -p /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/
tar -C /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/ -Jxf ~/centos7-rootfs.tar.xz
mkdir -p /var/lib/lxc-ns/${NSNAME}/${lxc_name}/rootfs/{proc,sys,dev,run,tmp}

./create_lxc_conf.sh --lxc-name ${lxc_name} \
    --interface "link=${outer_bridge_name},name=${outer_interface_name}" \
    --interface "link=${inner_bridge_name},name=${inner_interface_name}"

./create_hostname_conf_of_container.sh --lxc-name ${lxc_name} --hostname ${lxc_name}

# Inside the container

./create_fstab_conf_container.sh --lxc-name ${lxc_name}

./create_interface_conf_of_container.sh \
    --lxc-name ${lxc_name} --interface-name eth0 --ip 192.168.122.254 --netmask 255.255.255.0 --gateway 192.168.122.1 --dns 8.8.8.8

./create_interface_conf_of_container.sh \
    --lxc-name ${lxc_name} --interface-name eth1 --ip 172.31.0.1 --netmask 255.255.0.0

iptables -t nat -A POSTROUTING -o ${outer_interface_name} -j MASQUERADE
# or
# iptables -t nat -D POSTROUTING -s 172.31.0.0/16 -o veth-gw2 -j SNAT --to-source 192.168.122.254
# If you want to delete NAT rules
# iptables -t nat -F

```


