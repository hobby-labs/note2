# Creating MariaDB Cluster

## Prerequisites

| Servers  | SSH/Internet  | Service     | Heartbeat1   | Heartbeat2   | DRBD Data sync |
|          | 10.1.0.0/24   | 10.1.0.0/24 | 10.1.1.0/24  | 10.1.2.0/24  | 10.1.3.0/24    |
|          | eth0          | eth1        | eth2         | eth3         | eth4           |
|----------|---------------|-------------|--------------|--------------|----------------|
| VIP10X   | 172.31.101.10 | -           | -            | -            | -              |
| drbd101  | 172.31.101.11 | 10.1.0.11   | 10.1.1.11    | 10.1.2.11    | 10.1.3.11      |
| drbd102  | 172.31.101.12 | 10.1.0.12   | 10.1.1.12    | 10.1.2.12    | 10.1.3.12      |
| drbd103  | 172.31.101.13 | 10.1.0.13   | 10.1.1.13    | 10.1.2.13    | 10.1.3.13      |
| VIP20X   | 172.31.101.20 | -           | -            | -            | -              |
| drbd201  | 172.31.101.21 | 10.1.0.21   | 10.1.1.21    | 10.1.2.23    | 10.1.3.23      |
| drbd202  | 172.31.101.22 | 10.1.0.22   | 10.1.1.22    | 10.1.2.23    | 10.1.3.23      |
| drbd203  | 172.31.101.23 | 10.1.0.23   | 10.1.1.23    | 10.1.2.23    | 10.1.3.23      |
| VIP30X   | 172.31.101.30 | -           | -            | -            | -              |
| drbd301  | 172.31.101.31 | 10.1.0.31   | 10.1.1.31    | 10.1.2.33    | 10.1.3.33      |
| drbd302  | 172.31.101.32 | 10.1.0.32   | 10.1.1.32    | 10.1.2.33    | 10.1.3.33      |
| drbd303  | 172.31.101.33 | 10.1.0.33   | 10.1.1.33    | 10.1.2.33    | 10.1.3.33      |

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
cat >> /etc/hosts << 'EOF'
# Service
10.1.0.11  drbd101
10.1.0.12  drbd102
10.1.0.13  drbd103

# Heartbeat1
10.1.1.11  drbd101-hb1
10.1.1.12  drbd102-hb1
10.1.1.13  drbd103-hb1

# Heartbeat2
10.1.2.11  drbd101-hb2
10.1.2.12  drbd102-hb2
10.1.2.13  drbd103-hb2

# DRBD sync
10.1.3.11  drbd101-drbd
10.1.3.12  drbd102-drbd
10.1.3.13  drbd103-drbd
EOF

cat /etc/hosts
```

Stop SELinux and firewalld on all nodes.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
# Disable SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
setenforce 0

# Disable firewalld
systemctl stop firewalld
systemctl disable firewalld
```

Install DRBD 9 utils.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
yum install -y patch gcc make automake kernel-devel-$(uname -r) flex libxslt coccinelle
# Download DRBD utils
cd /usr/local/src
curl -LO https://pkg.linbit.com//downloads/drbd/utils/drbd-utils-9.29.0.tar.gz
tar xzf drbd-utils-9.29.0.tar.gz
cd drbd-utils-9.29.0
./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --without-manual
make
make install
```

Install DRBD kernel module.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
# Download DRBD kernel module source
cd /usr/local/src
curl -LO https://pkg.linbit.com//downloads/drbd/9/drbd-9.2.12.tar.gz
tar xzf drbd-9.2.12.tar.gz
cd drbd-9.2.12
make KDIR=/lib/modules/$(uname -r)/build
make install

depmod -a
echo "drbd" > /etc/modules-load.d/drbd.conf
modprobe drbd
lsmod | grep drbd
```

Prepare `/dev/vdb` for DRBD.

```
lsblk

> NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
> sr0              11:0    1 1024M  0 rom
> vda             252:0    0   50G  0 disk
> ├─vda1          252:1    0  200M  0 part /boot/efi
> ├─vda2          252:2    0    1G  0 part /boot
> └─vda3          252:3    0 40.8G  0 part
>   ├─centos-root 253:0    0 36.6G  0 lvm  /
>   └─centos-swap 253:1    0  4.2G  0 lvm  [SWAP]
> vdb             252:16   0    5G  0 disk
```

Configure DRBD resource.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
cat > /etc/drbd.d/global_common.conf << 'EOF'
global {
    usage-count no;
}

common {
    net {
        protocol C;
        allow-two-primaries no;
    }
    disk {
        on-io-error detach;
        resync-rate 100M;
    }
}
EOF

cat > /etc/drbd.d/mariadb.res << 'EOF'
resource mariadb {
    device    /dev/drbd0;
    disk      /dev/vdb;
    meta-disk internal;

    on drbd101 {
        address   10.1.3.11:7789;
        node-id   0;
    }
    on drbd102 {
        address   10.1.3.12:7789;
        node-id   1;
    }
    on drbd103 {
        address   10.1.3.13:7789;
        node-id   2;
    }

    connection-mesh {
        hosts drbd101 drbd102 drbd103;
    }
}
EOF
```

Initialize DRBD resource.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
# Create metadata on all nodes
drbdadm create-md mariadb

# Start DRBD on all nodes
drbdadm up mariadb
```

* drbd101: MariaDB Cluster 1
```
# Force drbd101 as the initial primary
drbdadm primary --force mariadb

# Watch sync progress
drbdadm status mariadb

# After sync completes, create filesystem on /dev/drbd0
mkfs.xfs /dev/drbd0
mkdir -p /var/lib/mysql
mount /dev/drbd0 /var/lib/mysql
df -h /var/lib/mysql

# Unmount for now (Pacemaker will manage this)
umount /var/lib/mysql
drbdadm secondary mariadb
```

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
rpm --import https://mariadb.org/mariadb_release_signing_key.pgp

cat > /etc/yum.repos.d/MariaDB.repo << 'EOF'
[mariadb]
name = MariaDB 10.6
baseurl = https://mirror.mariadb.org/yum/10.6/centos7-amd64
gpgkey = https://mariadb.org/mariadb_release_signing_key.pgp
gpgcheck = 1
module_hotfixes = 1
EOF

yum install -y MariaDB-server-10.6.19 MariaDB-client-10.6.19
```

* drbd101 only: MariaDB Cluster 1
```
# Temporarily make drbd101 primary and mount
drbdadm primary mariadb
mount /dev/drbd0 /var/lib/mysql

# Initialize MariaDB system tables
mysql_install_db --user=mysql --datadir=/var/lib/mysql

# Start MariaDB
systemctl start mariadb

# Secure installation
mariadb-secure-installation

# Stop MariaDB (Pacemaker will manage it)
systemctl stop mariadb
systemctl disable mariadb

# Unmount
umount /var/lib/mysql
drbdadm secondary mariadb
```

Disable MariaDB auto-start on all nodes.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
systemctl disable mariadb
```

## Configure Corosync and Pacemaker

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
yum install -y \
  git gcc gcc-c++ make automake autoconf libtool \
  pkgconfig git \
  nss-devel openssl-devel \
  libxml2-devel libxslt-devel \
  bzip2-devel \
  glib2-devel \
  libuuid-devel \
  pam-devel \
  python3-devel \
  dbus-devel \
  systemd-devel \
  zlib-devel \
  libaio-devel \
  lm_sensors-devel \
  net-snmp-devel \
  libcurl-devel \
  docbook-style-xsl \
  help2man \
  ncurses-devel \
  libtool-ltdl-devel \
  libyaml-devel
```

## install libqb (for corosync communication)

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
cd /usr/local/src
git clone https://github.com/ClusterLabs/libqb.git
cd libqb
git checkout v2.0.6
./autogen.sh
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc
make -j$(nproc)
make install
ldconfig

# Library is installed
ls -l /usr/lib64/libqb.so*
pkg-config --modversion libqb
> 2.0.6
```

## Install kronosnet (for corosync communication)

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
yum install -y lksctp-tools-devel doxygen libnl3-devel

cd /usr/local/src
wget -q https://github.com/kronosnet/kronosnet/archive/refs/tags/v1.20.tar.gz
tar xzf v1.20.tar.gz
cd kronosnet-1.20
./autogen.sh
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
  --disable-compress-zstd \
  --disable-compress-lz4 \
  --disable-compress-lzma \
  --disable-compress-bzip2 \
  --disable-compress-lzo2
make -j$(nproc)
make install
ldconfig
```

## Install corosync and pacemaker from source.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
cd /usr/local/src
wget -q https://github.com/corosync/corosync/archive/refs/tags/v3.1.0.tar.gz -O corosync-3.1.0.tar.gz
tar xzf corosync-3.1.0.tar.gz
cd corosync-3.1.0
./autogen.sh
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
  --localstatedir=/var \
  --with-systemddir=/usr/lib/systemd/system \
  --enable-systemd \
  CFLAGS="-DGIT_VERSION='\"v3.1.0\"'"

make -j$(nproc)
make install
ldconfig

# Fix version string if needed
pkg-config --modversion corosync

# Create user and directories
groupadd -r corosync 2>/dev/null || true
useradd -r -g corosync -d / -s /sbin/nologin corosync 2>/dev/null || true
mkdir -p /etc/corosync
mkdir -p /var/log/cluster
mkdir -p /var/lib/corosync

# Reload systemd
systemctl daemon-reload

# Verify
corosync -v
```

## Install pacemaker from source.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
cd /usr/local/src
wget -q https://github.com/ClusterLabs/resource-agents/archive/refs/tags/v4.7.0.tar.gz -O resource-agents-4.7.0.tar.gz
tar xzf resource-agents-4.7.0.tar.gz
cd resource-agents-4.7.0
./autogen.sh
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
  --localstatedir=/var \
  --with-rsctmpdir=/run/resource-agents
make -j$(nproc)
make install
```

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
yum install -y gnutls-devel

cd /usr/local/src
wget -q https://github.com/ClusterLabs/pacemaker/archive/refs/tags/Pacemaker-2.0.5.tar.gz
tar xzf Pacemaker-2.0.5.tar.gz
cd pacemaker-Pacemaker-2.0.5
./autogen.sh
./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
  --localstatedir=/var \
  --with-systemdsystemunitdir=/usr/lib/systemd/system \
  --with-corosync
make -j$(nproc)
make install
ldconfig

# Create user and directories
groupadd -r haclient 2>/dev/null || true
useradd -r -g haclient -d /var/lib/pacemaker -s /sbin/nologin hacluster 2>/dev/null || true
mkdir -p /var/lib/pacemaker/{cib,cores,pengine}
chown -R hacluster:haclient /var/lib/pacemaker
mkdir -p /var/log/pacemaker
chown hacluster:haclient /var/log/pacemaker
systemctl daemon-reload

# Verify
pacemakerd --version
crm_mon --version
cibadmin --version
```

--- Snapshot init_empty_cluster (Restart drbd if rebooted) ---

# Configure Corosync

* drbd101 only: MariaDB Cluster 1
```
# On drbd101 only - generate auth key
corosync-keygen
```

* drbd102, drbd103: MariaDB Cluster 1
```
# Copy to other nodes
scp /etc/corosync/authkey drbd102:/etc/corosync/authkey
scp /etc/corosync/authkey drbd103:/etc/corosync/authkey
```

* drbd102, drbd103: MariaDB Cluster 1
```
chmod 400 /etc/corosync/authkey
chown root:root /etc/corosync/authkey
```

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
cat > /etc/corosync/corosync.conf << 'EOF'
totem {
    version: 2
    cluster_name: mariadb_cluster
    transport: knet
    crypto_cipher: aes256
    crypto_hash: sha256
}

nodelist {
    node {
        ring0_addr: 10.1.1.11
        ring1_addr: 10.1.2.11
        name: drbd101
        nodeid: 1
    }
    node {
        ring0_addr: 10.1.1.12
        ring1_addr: 10.1.2.12
        name: drbd102
        nodeid: 2
    }
    node {
        ring0_addr: 10.1.1.13
        ring1_addr: 10.1.2.13
        name: drbd103
        nodeid: 3
    }
}

quorum {
    provider: corosync_votequorum
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
    timestamp: on
}
EOF
```

Start and enable corosync and pacemaker on all nodes.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
systemctl start corosync
systemctl start pacemaker
systemctl enable corosync
systemctl enable pacemaker

# Verify corosync members
corosync-cmapctl | grep members

# Verify pacemaker
crm_mon -1
```

* drbd101 only: MariaDB Cluster 1
```
crm_attribute --type crm_config --name stonith-enabled --update false
crm_attribute --type crm_config --name no-quorum-policy --update ignore

# Modify CIB
cibadmin --query > /tmp/cib.xml
sed -i.bak 's|<constraints/>|<constraints/>\n  <rsc_defaults>\n    <meta_attributes id="rsc-options">\n      <nvpair id="rsc-options-resource-stickiness" name="resource-stickiness" value="100"/>\n    </meta_attributes>\n  </rsc_defaults>|' /tmp/cib.xml
grep -A4 'rsc_defaults' /tmp/cib.xml
cibadmin --replace --xml-file /tmp/cib.xml
cibadmin --query --scope rsc_defaults
> # Expected output
> <rsc_defaults>
>   <meta_attributes id="rsc-options">
>     <nvpair id="rsc-options-resource-stickiness" name="resource-stickiness" value="100"/>
>   </meta_attributes>
> </rsc_defaults>
```

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
drbdadm secondary mariadb
```

* drbd101 only: MariaDB Cluster 1
```
cibadmin --query > /tmp/cib.xml

sed -i.bak 's|<resources/>|<resources>\
  <master id="ms_drbd_mariadb">\
    <meta_attributes id="ms_drbd_mariadb-meta">\
      <nvpair id="ms_drbd_mariadb-promoted-max" name="promoted-max" value="1"/>\
      <nvpair id="ms_drbd_mariadb-promoted-node-max" name="promoted-node-max" value="1"/>\
      <nvpair id="ms_drbd_mariadb-clone-max" name="clone-max" value="3"/>\
      <nvpair id="ms_drbd_mariadb-clone-node-max" name="clone-node-max" value="1"/>\
      <nvpair id="ms_drbd_mariadb-notify" name="notify" value="true"/>\
    </meta_attributes>\
    <primitive id="drbd_mariadb" class="ocf" provider="linbit" type="drbd">\
      <instance_attributes id="drbd_mariadb-attrs">\
        <nvpair id="drbd_mariadb-drbd_resource" name="drbd_resource" value="mariadb"/>\
      </instance_attributes>\
      <operations>\
        <op id="drbd_mariadb-monitor-master" name="monitor" interval="30s" role="Master"/>\
        <op id="drbd_mariadb-monitor-slave" name="monitor" interval="60s" role="Slave"/>\
      </operations>\
    </primitive>\
  </master>\
</resources>|' /tmp/cib.xml

grep -A20 '<resources>' /tmp/cib.xml
cibadmin --replace --xml-file /tmp/cib.xml

sleep 10
crm_mon -1

```

//////// Next instructions will fail after `cibadmin --replace --xml-file /tmp/cib.xml`.
//////// Call cib_replace failed (-203): Update does not conform to the configured schema
Add resource group and constraints.

```
yum install psmisc

systemctl start corosync
systemctl start pacemaker

crm_attribute --type crm_config --name stonith-enabled --update false
crm_attribute --type crm_config --name no-quorum-policy --update ignore
```


| Command                              | Description                 |
|--------------------------------------|-----------------------------|
| pcs status                           | Overall cluster status      |
| pcs resource show                    | List all resources          |
| pcs cluster stop --all               | Stop cluster on all nodes   |
| pcs cluster start --all              | Start cluster on all nodes  |
| pcs node standby <node>              | Put node in standby         |
| pcs node unstandby <node>            | Remove node from standby    |
| pcs resource move svc_mariadb <node> | Move resource to node       |
| pcs resource clear svc_mariadb       | Clear resource constraints  |
| pcs resource cleanup                 | Clear failed actions        |
| drbdadm status mariadb               | DRBD replication status     |
| crm_mon -1                           | One-shot cluster monitor    |
