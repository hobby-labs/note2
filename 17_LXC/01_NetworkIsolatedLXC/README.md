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

# Initialize cpuset for the lxc cgroup.
#
# Background: A cgroup (control group) is a Linux kernel mechanism that limits
# and isolates resource usage (CPU, memory, etc.) for a group of processes.
# When lxc-start launches a container, it writes the container's first process
# (init, PID 1) into the cgroup by writing its PID to the cgroup's "tasks" file
# (e.g. /sys/fs/cgroup/cpuset/lxc/<container>/tasks). This is what "moving a
# task into a cgroup" means — the kernel then enforces that cgroup's resource
# limits on that process and all its children.
#
# The cpuset subsystem is special: it controls WHICH CPU cores and memory nodes
# a process is allowed to use. Unlike other subsystems, cpuset requires
# cpuset.cpus and cpuset.mems to be set BEFORE any process can be assigned.
# If they are empty, the kernel rejects the write to the tasks file with
# "No space left on device" or "Write error", and lxc-start fails.
#
# We copy the parent's values so LXC containers can use all available CPUs and
# memory nodes, matching the host's topology.
cat /sys/fs/cgroup/cpuset/cpuset.cpus > /sys/fs/cgroup/cpuset/lxc/cpuset.cpus
cat /sys/fs/cgroup/cpuset/cpuset.mems > /sys/fs/cgroup/cpuset/lxc/cpuset.mems

# Enable clone_children so child cgroups inherit cpuset values automatically.
# When lxc-start creates per-container child cgroups under /sys/fs/cgroup/cpuset/lxc/,
# this flag makes the kernel auto-populate cpuset.cpus and cpuset.mems in each child,
# so we don't have to manually initialize every new container's cpuset.
echo 1 > /sys/fs/cgroup/cpuset/lxc/cgroup.clone_children
-----

ip netns exec ns01 ./create_bridge.sh --bridge-name ns01-br00
ip netns exec ns01 ./create_bridge.sh --bridge-name ns01-br01
ip netns exec ns01 ./create_bridge.sh --bridge-name ns01-br98
ip netns exec ns01 ./create_bridge.sh --bridge-name ns01-br99

ip link add eth-ns01-vb0 type veth peer name veth-ns01-vb0
brctl addif virbr0 veth-ns01-vb0
ip link set veth-ns01-vb0 up
ip link set eth-ns01-vb0 netns ns01
ip netns exec ns01 ip link set eth-ns01-vb0 up

# ip link add eth-ns01-br00 type veth peer name veth-ns01-br00
# ip link set veth-ns01-br00 up
# ip link set eth-ns01-br00 netns ns01
# ip netns exec ns01 brctl addif ns01-br00 eth-ns01-br00
# ip netns exec ns01 ip link set eth-ns01-br00 up

ns_name=ns01
./enter_ns.sh --ns-name ${ns_name}

ip addr add 172.31.0.1/16 dev ns01-br00
ip link set ns01-br00 up
ip link set ns01-br01 up
ip link set ns01-br98 up
ip addr add 172.16.0.1/16 dev ns01-br99
ip link set ns01-br99 up

ip addr add 192.168.122.254/24 dev eth-ns01-vb0
ip link set eth-ns01-vb0 up
ip route add default via 192.168.122.1 dev eth-ns01-vb0

# Create iptables rules for NAT and forwarding outside the namespace eg internet access
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -j MASQUERADE -o eth-ns01-vb0 -s 172.31.0.0/16
iptables -t nat -A POSTROUTING -j MASQUERADE -o eth-ns01-vb0 -s 172.16.0.0/16

# Creating app-server01 container in ns01 #########################################################################

lxc_name=app-server01
mng_bridge_name=ns01-br99
mng_interface_name=eth0
service_bridge_name=ns01-br00
service_interface_name=eth1
db_bridge_name=ns01-br01
db_interface_name=eth2

mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/
tar -C /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/ -Jxf ~/centos7-rootfs.tar.xz
mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/{proc,sys,dev,run,tmp}

./create_lxc_conf.sh --lxc-name ${lxc_name} \
    --interface "bind_bridge=${mng_bridge_name},interface_name=${mng_interface_name}" \
    --interface "bind_bridge=${service_bridge_name},interface_name=${service_interface_name}" \
    --interface "bind_bridge=${db_bridge_name},interface_name=${db_interface_name}"

./inside/container/create_hostname_conf.sh --lxc-name ${lxc_name} --hostname ${lxc_name}
./inside/container/create_fstab_conf.sh --lxc-name ${lxc_name}

./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth0 --ip 172.16.1.11 --netmask 255.255.0.0 --gateway 172.16.0.1 --dns 8.8.8.8
./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth1 --ip 172.31.1.11 --netmask 255.255.0.0
./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth2 --ip 172.30.1.11 --netmask 255.255.0.0

# Now start the container
lxc-start --name ${lxc_name}

# Creating app-server02 container in ns01 #########################################################################

lxc_name=app-server02

mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/
tar -C /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/ -Jxf ~/centos7-rootfs.tar.xz
mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/{proc,sys,dev,run,tmp}

./create_lxc_conf.sh --lxc-name ${lxc_name} \
    --interface "bind_bridge=${mng_bridge_name},interface_name=${mng_interface_name}" \
    --interface "bind_bridge=${service_bridge_name},interface_name=${service_interface_name}" \
    --interface "bind_bridge=${db_bridge_name},interface_name=${db_interface_name}"

./inside/container/create_hostname_conf.sh --lxc-name ${lxc_name} --hostname ${lxc_name}
./inside/container/create_fstab_conf.sh --lxc-name ${lxc_name}

./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth0 --ip 172.16.1.12 --netmask 255.255.0.0 --gateway 172.16.0.1 --dns 8.8.8.8
./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth1 --ip 172.31.1.12 --netmask 255.255.0.0
./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth2 --ip 172.30.1.12 --netmask 255.255.0.0
# Now start the container
lxc-start --name ${lxc_name}

# Creating db-server01 container in ns01 #########################################################################

lxc_name=db-server01
db_bridge_name=ns01-br01
db_interface_name=eth1

mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/
tar -C /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/ -Jxf ~/centos7-rootfs.tar.xz
mkdir -p /var/lib/lxc-ns/${NS_NAME}/${lxc_name}/rootfs/{proc,sys,dev,run,tmp}

./create_lxc_conf.sh --lxc-name ${lxc_name} \
    --interface "bind_bridge=${mng_bridge_name},interface_name=${mng_interface_name}" \
    --interface "bind_bridge=${db_bridge_name},interface_name=${db_interface_name}"

./inside/container/create_hostname_conf.sh --lxc-name ${lxc_name} --hostname ${lxc_name}
./inside/container/create_fstab_conf.sh --lxc-name ${lxc_name}

./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth0 --ip 172.16.101.11 --netmask 255.255.0.0 --gateway 172.16.0.1 --dns 8.8.8.8
./inside/container/create_interface_conf.sh \
    --lxc-name ${lxc_name} --interface-name eth1 --ip 172.30.101.11 --netmask 255.255.0.0
# Now start the container
lxc-start --name ${lxc_name}

