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
# Disable unused services when running in a container to omit unnecessary logs.
systemctl disable plymouth-start.service
systemctl disable auditd.service
systemctl disable qemu-guest-agent.service
systemctl mask plymouth-start.service
systemctl mask auditd.service
systemctl mask qemu-guest-agent.service

XZ_OPT='-9 -T0' tar -C / --numeric-owner --exclude=./proc --exclude=./sys --exclude=./dev \
    --exclude=./run --exclude=./tmp --exclude=./mnt --exclude=./media \
    -Jcf centos7-rootfs.tar.xz .
```

Download a CentOS7 rootfs tarball from a trusted source or create your own as shown above.

<!--
Snapshot name: lxc_installed
-->

Creating bridges.

------------------------------------------------------------------------------------------

* Creating ns01
```
ip netns add ns01

-----
#mount | grep cgroup
#
## If not mounted, mount it
#mount -t tmpfs cgroup_root /sys/fs/cgroup
#
## Mount each cgroup subsystem
#for subsys in cpuset cpu cpuacct blkio memory devices freezer net_cls perf_event hugetlb; do
#    mkdir -p /sys/fs/cgroup/${subsys}
#    mount -t cgroup -o ${subsys} cgroup /sys/fs/cgroup/${subsys} 2>/dev/null || true
#done
#
## Also mount the systemd cgroup if needed
#mkdir -p /sys/fs/cgroup/systemd
#mount -t cgroup -o name=systemd cgroup /sys/fs/cgroup/systemd 2>/dev/null || true

--

for dir in /sys/fs/cgroup/*/; do
    echo "mkdir -p ${dir}lxc"
    mkdir -p "${dir}lxc" 2>/dev/null
done

# Initialize cpuset
cat /sys/fs/cgroup/cpuset/cpuset.cpus > /sys/fs/cgroup/cpuset/lxc/cpuset.cpus
cat /sys/fs/cgroup/cpuset/cpuset.mems > /sys/fs/cgroup/cpuset/lxc/cpuset.mems

# Enable clone_children so child cgroups inherit cpuset values automatically
echo 1 > /sys/fs/cgroup/cpuset/lxc/cgroup.clone_children
-----



ip netns exec ns01 ./create_bridge.sh --bridge-name ns01-br00
ip netns exec ns01 ./create_bridge.sh --bridge-name ns01-br01
ip netns exec ns01 ./create_bridge.sh --bridge-name ns01-br99

ip link add eth-ns01-vb0 type veth peer name veth-ns01-vb0
brctl addif virbr0 veth-ns01-vb0
ip link set veth-ns01-vb0 up
ip link set eth-ns01-vb0 netns ns01
ip netns exec ns01 ip link set eth-ns01-vb0 up

ip link add eth-ns01-br00 type veth peer name veth-ns01-br00
ip link set veth-ns01-br00 up
ip link set eth-ns01-br00 netns ns01
ip netns exec ns01 brctl addif ns01-br00 eth-ns01-br00
ip netns exec ns01 ip link set eth-ns01-br00 up

ns_name=ns01
./enter_ns.sh --ns-name ${ns_name}

ip addr add 172.31.0.1/16 dev ns01-br00
ip link set ns01-br00 up

ip addr add 192.168.122.254/24 dev eth-ns01-vb0
ip link set eth-ns01-vb0 up
ip route add default via 192.168.122.1 dev eth-ns01-vb0

lxc_name=lxc-guest01
outer_bridge_name=ns01-br00
outer_interface_name=eth0
inner_bridge_name=ns01-br99
inner_interface_name=eth1

mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/
tar -C /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/ -Jxf ~/centos7-rootfs.tar.xz
mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/{proc,sys,dev,run,tmp}

./create_lxc_conf.sh --lxc-name ${lxc_name} \
    --interface "bind_bridge=${outer_bridge_name},interface_name=${outer_interface_name}" \
    --interface "bind_bridge=${inner_bridge_name},interface_name=${inner_interface_name}"

./inside/container/create_hostname_conf.sh --lxc-name ${lxc_name} --hostname ${lxc_name}
./inside/container/create_fstab_conf.sh --lxc-name ${lxc_name}

./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth0 --ip 172.31.0.11 --netmask 255.255.0.0 --gateway 172.31.0.1 --dns 8.8.8.8

./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth1 --ip 172.16.0.1 --netmask 255.255.0.0

# Now start the container
lxc-start --name lxc-guest01



lxc-start --name lxc-guest01 --logfile /var/tmp/log2.log


# In ns1
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -j MASQUERADE -o eth-ns01-vb0 -s 172.31.0.0/16

