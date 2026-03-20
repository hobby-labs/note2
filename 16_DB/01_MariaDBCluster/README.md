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

* drbd101, drbd102, drbd103
```
# On drbd101, drbd102, drbd103
mkdir -p /var/log/mariadb/slowlog
chown -R mysql:mysql /var/log/mariadb
chmod 750 /var/log/mariadb
chmod 750 /var/log/mariadb/slowlog

cat > /etc/my.cnf.d/server.cnf << 'EOF'
[mysqld]
# === Data Directory (on DRBD) ===
datadir=/var/lib/mysql/data

# === Socket and PID (local) ===
socket=/var/lib/mysql/mysql.sock
pid-file=/var/run/mariadb/mariadb.pid

# === Temp Directory (local) ===
tmpdir=/tmp

# === InnoDB Redo Logs (on DRBD — default location /var/lib/mysql/) ===
# innodb_log_group_home_dir=/var/lib/mysql/
# (Default is datadir parent, which is /var/lib/mysql/ — no change needed)

# === InnoDB System Tablespace (on DRBD) ===
innodb_data_home_dir=/var/lib/mysql/
innodb_data_file_path=ibdata1:12M:autoextend

# === Aria Logs (on DRBD) ===
aria_log_dir_path=/var/lib/mysql/

# === Binary Logs (on DRBD) ===
log_bin=/var/lib/mysql/log/binary/binlog
log_bin_index=/var/lib/mysql/log/binary/binlog.index
expire_logs_days=7
max_binlog_size=100M

# === Error Log (local) ===
log_error=/var/log/mariadb/error.log

# === General Log (local — disabled by default, enable for debugging) ===
general_log=0
general_log_file=/var/log/mariadb/general.log

# === Slow Query Log (local) ===
slow_query_log=1
slow_query_log_file=/var/log/mariadb/slowlog/slow.log
long_query_time=1

# === Character Set ===
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci

# === InnoDB Settings ===
innodb_buffer_pool_size=512M
innodb_log_file_size=64M
innodb_flush_log_at_trx_commit=1
innodb_file_per_table=1

[mysqld_safe]
log-error=/var/log/mariadb/error.log
EOF
```

* drbd101 only: MariaDB Cluster 1
```
# Temporarily make drbd101 primary and mount
drbdadm primary mariadb
mount /dev/drbd0 /var/lib/mysql

# Initialize MariaDB system tables
mysql_install_db --user=mysql --datadir=/var/lib/mysql/data

# Create binary log directory
mkdir -p /var/lib/mysql/log/binary
chown -R mysql:mysql /var/lib/mysql/log
chmod 750 /var/lib/mysql/log
chmod 750 /var/lib/mysql/log/binary

# Start MariaDB
systemctl start mariadb

# Secure installation (Specify "secret" as root password only in development environment. Answer "Y" to all questions.)
mariadb-secure-installation

cat > /root/.my.cnf << 'EOF'
[client]
user=root
password=secret
EOF

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

--- Snapshot init_empty_cluster (Restart drbd if rebooted: systemctl restart drbd) ---

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

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
yum install -y psmisc
```

* drbd101 only: MariaDB Cluster 1
```
cibadmin --query > /tmp/cib.xml

python2 << 'PYEOF'
import xml.etree.ElementTree as ET

tree = ET.parse('/tmp/cib.xml')
root = tree.getroot()
config = root.find('configuration')
resources = config.find('resources')
constraints = config.find('constraints')

# Add group
group = ET.SubElement(resources, 'group')
group.set('id', 'grp_mariadb')

fs = ET.SubElement(group, 'primitive')
fs.set('id', 'fs_mariadb')
fs.set('class', 'ocf')
fs.set('provider', 'heartbeat')
fs.set('type', 'Filesystem')
fs_inst = ET.SubElement(fs, 'instance_attributes')
fs_inst.set('id', 'fs_mariadb-attrs')
for nv_id, name, value in [
    ('fs_mariadb-device', 'device', '/dev/drbd0'),
    ('fs_mariadb-directory', 'directory', '/var/lib/mysql'),
    ('fs_mariadb-fstype', 'fstype', 'xfs'),
]:
    nv = ET.SubElement(fs_inst, 'nvpair')
    nv.set('id', nv_id)
    nv.set('name', name)
    nv.set('value', value)
fs_ops = ET.SubElement(fs, 'operations')
op = ET.SubElement(fs_ops, 'op')
op.set('id', 'fs_mariadb-monitor')
op.set('name', 'monitor')
op.set('interval', '20s')

svc = ET.SubElement(group, 'primitive')
svc.set('id', 'svc_mariadb')
svc.set('class', 'systemd')
svc.set('type', 'mariadb')
svc_ops = ET.SubElement(svc, 'operations')
op = ET.SubElement(svc_ops, 'op')
op.set('id', 'svc_mariadb-monitor')
op.set('name', 'monitor')
op.set('interval', '30s')
op = ET.SubElement(svc_ops, 'op')
op.set('id', 'svc_mariadb-start')
op.set('name', 'start')
op.set('interval', '0')
op.set('timeout', '120s')
op = ET.SubElement(svc_ops, 'op')
op.set('id', 'svc_mariadb-stop')
op.set('name', 'stop')
op.set('interval', '0')
op.set('timeout', '120s')

vip = ET.SubElement(group, 'primitive')
vip.set('id', 'vip_mariadb')
vip.set('class', 'ocf')
vip.set('provider', 'heartbeat')
vip.set('type', 'IPaddr2')
vip_inst = ET.SubElement(vip, 'instance_attributes')
vip_inst.set('id', 'vip_mariadb-attrs')
for nv_id, name, value in [
    ('vip_mariadb-ip', 'ip', '10.1.0.10'),
    ('vip_mariadb-cidr_netmask', 'cidr_netmask', '24'),
    ('vip_mariadb-nic', 'nic', 'eth1'),
]:
    nv = ET.SubElement(vip_inst, 'nvpair')
    nv.set('id', nv_id)
    nv.set('name', name)
    nv.set('value', value)
vip_ops = ET.SubElement(vip, 'operations')
op = ET.SubElement(vip_ops, 'op')
op.set('id', 'vip_mariadb-monitor')
op.set('name', 'monitor')
op.set('interval', '10s')

# Add constraints
col = ET.SubElement(constraints, 'rsc_colocation')
col.set('id', 'col_grp_drbd')
col.set('rsc', 'grp_mariadb')
col.set('with-rsc', 'ms_drbd_mariadb')
col.set('with-rsc-role', 'Master')
col.set('score', 'INFINITY')

order = ET.SubElement(constraints, 'rsc_order')
order.set('id', 'ord_drbd_grp')
order.set('first', 'ms_drbd_mariadb')
order.set('then', 'grp_mariadb')
order.set('then-action', 'start')

tree.write('/tmp/cib_new.xml', xml_declaration=True, encoding='UTF-8')
print('Done')
PYEOF


# Validate before applying
xmllint --relaxng /usr/share/pacemaker/pacemaker-3.5.rng /tmp/cib_new.xml 2>&1 | tail -1

# Apply
cibadmin --replace --xml-file /tmp/cib_new.xml

sleep 15
crm_mon -1
```

Grant MariaDB access to cluster nodes.

* drbd101 only: MariaDB Cluster 1
```
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'10.1.0.%' IDENTIFIED BY 'secret' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"
```

Verify stonith status.
```
crm_attribute --type crm_config --name stonith-enabled --query
> scope=crm_config  name=stonith-enabled value=true
crm_attribute --type crm_config --name stonith-watchdog-timeout --query
> scope=crm_config  name=stonith-watchdog-timeout value=30
```

# Create sample data

Create files below first.

* 01_create_schema.sql
```
[root@drbd101 ~]# cat > 01_create_schema.sql << 'EOF'
-- Create database
CREATE DATABASE IF NOT EXISTS grocery_store;
USE grocery_store;

-- Customers table
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    address VARCHAR(200),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Product categories table
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Products table
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    unit VARCHAR(20) NOT NULL DEFAULT 'each',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
) ENGINE=InnoDB;

-- Transactions table (header)
CREATE TABLE transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    payment_method ENUM('cash', 'credit_card', 'debit_card', 'e_money') NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

-- Transaction details table (line items)
CREATE TABLE transaction_details (
    detail_id INT AUTO_INCREMENT PRIMARY KEY,
    transaction_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;
EOF
```

* 02_insert_sample_data.sql
```
[root@drbd101 ~]# cat > 02_insert_sample_data.sql << 'EOF'
USE grocery_store;

-- Insert categories
INSERT INTO categories (category_name) VALUES
('Fruits'),
('Vegetables'),
('Dairy'),
('Meat'),
('Beverages'),
('Bakery'),
('Snacks'),
('Frozen Foods');

-- Insert products
INSERT INTO products (product_name, category_id, price, stock_quantity, unit) VALUES
-- Fruits
('Apple (Fuji)', 1, 1.50, 200, 'each'),
('Banana', 1, 0.30, 300, 'each'),
('Strawberry Pack', 1, 3.99, 50, 'pack'),
('Orange', 1, 1.20, 150, 'each'),
('Grape (Red)', 1, 4.50, 80, 'pack'),
-- Vegetables
('Tomato', 2, 0.80, 180, 'each'),
('Cucumber', 2, 0.60, 120, 'each'),
('Lettuce', 2, 1.50, 90, 'head'),
('Carrot', 2, 0.50, 200, 'each'),
('Onion', 2, 0.70, 250, 'each'),
-- Dairy
('Whole Milk 1L', 3, 2.50, 100, 'bottle'),
('Yogurt (Plain)', 3, 1.80, 80, 'cup'),
('Cheddar Cheese', 3, 4.99, 60, 'block'),
('Butter 200g', 3, 3.20, 70, 'pack'),
('Eggs (10 pack)', 3, 3.50, 120, 'pack'),
-- Meat
('Chicken Breast 500g', 4, 5.99, 40, 'pack'),
('Ground Beef 500g', 4, 6.50, 35, 'pack'),
('Pork Loin 500g', 4, 7.20, 30, 'pack'),
('Salmon Fillet 300g', 4, 8.99, 25, 'pack'),
('Bacon 200g', 4, 4.50, 45, 'pack'),
-- Beverages
('Green Tea 500ml', 5, 1.50, 200, 'bottle'),
('Orange Juice 1L', 5, 3.20, 80, 'bottle'),
('Cola 500ml', 5, 1.80, 150, 'bottle'),
('Mineral Water 500ml', 5, 0.99, 300, 'bottle'),
('Coffee (Canned)', 5, 1.20, 100, 'can'),
-- Bakery
('White Bread', 6, 2.50, 60, 'loaf'),
('Croissant', 6, 1.80, 40, 'each'),
('Bagel', 6, 1.50, 50, 'each'),
-- Snacks
('Potato Chips', 7, 2.99, 100, 'bag'),
('Chocolate Bar', 7, 1.50, 120, 'each'),
('Mixed Nuts', 7, 4.50, 60, 'bag'),
-- Frozen Foods
('Ice Cream 1L', 8, 5.50, 40, 'tub'),
('Frozen Pizza', 8, 4.99, 35, 'box'),
('Frozen Vegetables Mix', 8, 2.99, 50, 'bag');

-- Insert customers
INSERT INTO customers (first_name, last_name, email, phone, address) VALUES
('Taro', 'Yamada', 'taro.yamada@example.com', '090-1234-5678', 'Tokyo, Shibuya-ku 1-2-3'),
('Hanako', 'Suzuki', 'hanako.suzuki@example.com', '090-2345-6789', 'Tokyo, Shinjuku-ku 4-5-6'),
('Ken', 'Tanaka', 'ken.tanaka@example.com', '090-3456-7890', 'Osaka, Namba 7-8-9'),
('Yuki', 'Sato', 'yuki.sato@example.com', '090-4567-8901', 'Kyoto, Gion 10-11-12'),
('Akiko', 'Watanabe', 'akiko.watanabe@example.com', '090-5678-9012', 'Nagoya, Sakae 13-14-15'),
('Kenji', 'Takahashi', 'kenji.takahashi@example.com', '090-6789-0123', 'Fukuoka, Hakata 16-17-18'),
('Mika', 'Ito', 'mika.ito@example.com', '090-7890-1234', 'Sapporo, Susukino 19-20-21'),
('Ryo', 'Kobayashi', 'ryo.kobayashi@example.com', '090-8901-2345', 'Kobe, Sannomiya 22-23-24');

-- Insert transactions
INSERT INTO transactions (customer_id, transaction_date, total_amount, payment_method) VALUES
(1, '2026-03-10 09:15:00', 15.30, 'credit_card'),
(2, '2026-03-10 10:30:00', 22.47, 'cash'),
(3, '2026-03-10 11:45:00', 8.90, 'e_money'),
(1, '2026-03-11 09:00:00', 31.68, 'debit_card'),
(4, '2026-03-11 14:20:00', 12.50, 'credit_card'),
(5, '2026-03-12 08:30:00', 45.96, 'credit_card'),
(6, '2026-03-12 12:00:00', 9.80, 'cash'),
(7, '2026-03-13 16:45:00', 27.47, 'e_money'),
(2, '2026-03-13 17:30:00', 18.98, 'debit_card'),
(8, '2026-03-14 10:00:00', 35.46, 'credit_card');

-- Insert transaction details
-- Transaction 1: Taro buys fruits and milk
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(1, 1, 3, 1.50, 4.50),   -- 3x Apple
(1, 2, 6, 0.30, 1.80),   -- 6x Banana
(1, 11, 2, 2.50, 5.00),  -- 2x Milk
(1, 21, 2, 1.50, 3.00),  -- 2x Green Tea
(1, 24, 1, 0.99, 0.99);  -- 1x Mineral Water

-- Transaction 2: Hanako buys vegetables and cheese
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(2, 6, 4, 0.80, 3.20),   -- 4x Tomato
(2, 8, 2, 1.50, 3.00),   -- 2x Lettuce
(2, 13, 1, 4.99, 4.99),  -- 1x Cheddar Cheese
(2, 15, 1, 3.50, 3.50),  -- 1x Eggs
(2, 27, 2, 1.80, 3.60),  -- 2x Croissant
(2, 7, 3, 0.60, 1.80),   -- 3x Cucumber
(2, 28, 1, 1.50, 1.50);  -- 1x Bagel

-- Transaction 3: Ken buys snacks
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(3, 29, 1, 2.99, 2.99),  -- 1x Potato Chips
(3, 30, 2, 1.50, 3.00),  -- 2x Chocolate Bar
(3, 23, 1, 1.80, 1.80),  -- 1x Cola
(3, 25, 1, 1.20, 1.20);  -- 1x Coffee

-- Transaction 4: Taro buys meat and frozen foods
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(4, 16, 2, 5.99, 11.98), -- 2x Chicken Breast
(4, 19, 1, 8.99, 8.99),  -- 1x Salmon Fillet
(4, 32, 1, 5.50, 5.50),  -- 1x Ice Cream
(4, 33, 1, 4.99, 4.99);  -- 1x Frozen Pizza

-- Transaction 5: Yuki buys dairy and bakery
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(5, 11, 1, 2.50, 2.50),  -- 1x Milk
(5, 12, 2, 1.80, 3.60),  -- 2x Yogurt
(5, 14, 1, 3.20, 3.20),  -- 1x Butter
(5, 26, 1, 2.50, 2.50);  -- 1x White Bread

-- Transaction 6: Akiko buys a big order
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(6, 16, 2, 5.99, 11.98), -- 2x Chicken Breast
(6, 17, 1, 6.50, 6.50),  -- 1x Ground Beef
(6, 18, 1, 7.20, 7.20),  -- 1x Pork Loin
(6, 1, 4, 1.50, 6.00),   -- 4x Apple
(6, 3, 2, 3.99, 7.98),   -- 2x Strawberry Pack
(6, 9, 5, 0.50, 2.50),   -- 5x Carrot
(6, 10, 3, 0.70, 2.10),  -- 3x Onion
(6, 22, 1, 3.20, 3.20);  -- 1x Orange Juice

-- Transaction 7: Kenji buys beverages
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(7, 21, 2, 1.50, 3.00),  -- 2x Green Tea
(7, 23, 2, 1.80, 3.60),  -- 2x Cola
(7, 24, 2, 0.99, 1.98),  -- 2x Mineral Water
(7, 25, 1, 1.20, 1.20);  -- 1x Coffee

-- Transaction 8: Mika buys various items
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(8, 5, 1, 4.50, 4.50),   -- 1x Grape
(8, 19, 1, 8.99, 8.99),  -- 1x Salmon Fillet
(8, 20, 1, 4.50, 4.50),  -- 1x Bacon
(8, 31, 1, 4.50, 4.50),  -- 1x Mixed Nuts
(8, 34, 1, 2.99, 2.99),  -- 1x Frozen Vegetables
(8, 24, 2, 0.99, 1.98);  -- 2x Mineral Water

-- Transaction 9: Hanako buys again
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(9, 3, 1, 3.99, 3.99),   -- 1x Strawberry Pack
(9, 4, 3, 1.20, 3.60),   -- 3x Orange
(9, 12, 2, 1.80, 3.60),  -- 2x Yogurt
(9, 26, 1, 2.50, 2.50),  -- 1x White Bread
(9, 30, 2, 1.50, 3.00),  -- 2x Chocolate Bar
(9, 7, 2, 0.60, 1.20);   -- 2x Cucumber

-- Transaction 10: Ryo buys a big order
INSERT INTO transaction_details (transaction_id, product_id, quantity, unit_price, subtotal) VALUES
(10, 16, 1, 5.99, 5.99),  -- 1x Chicken Breast
(10, 17, 1, 6.50, 6.50),  -- 1x Ground Beef
(10, 15, 2, 3.50, 7.00),  -- 2x Eggs
(10, 11, 1, 2.50, 2.50),  -- 1x Milk
(10, 14, 1, 3.20, 3.20),  -- 1x Butter
(10, 6, 3, 0.80, 2.40),   -- 3x Tomato
(10, 8, 1, 1.50, 1.50),   -- 1x Lettuce
(10, 29, 1, 2.99, 2.99),  -- 1x Potato Chips
(10, 21, 2, 1.50, 3.00);  -- 2x Green Tea
EOF
```

Run queries create schema, insert sample data, and run sample queries.

* drbd101
```
[root@drbd101 ~]# mysql -u root -p=secret < 01_create_schema.sql
[root@drbd101 ~]# mysql -u root -p=secret < 02_insert_sample_data.sql

[root@drbd101 ~]# # Count records
[root@drbd101 ~]# mysql --defaults-extra-file=/root/.my.cnf -D grocery_store -e "
SELECT 'categories' AS tbl, COUNT(*) AS cnt FROM categories
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL SELECT 'transaction_details', COUNT(*) FROM transaction_details;
"
> +---------------------+-----+
> | tbl                 | cnt |
> +---------------------+-----+
> | categories          |   8 |
> | products            |  34 |
> | customers           |   8 |
> | transactions        |  10 |
> | transaction_details |  57 |
> +---------------------+-----+

[root@drbd101 ~]# # Top spending customers
[root@drbd101 ~]# mysql --defaults-extra-file=/root/.my.cnf -D grocery_store -e "
SELECT
    c.first_name,
    c.last_name,
    COUNT(DISTINCT t.transaction_id) AS num_transactions,
    SUM(t.total_amount) AS total_spent
FROM customers c
JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY c.customer_id
ORDER BY total_spent DESC;
"
> +------------+-----------+------------------+-------------+
> | first_name | last_name | num_transactions | total_spent |
> +------------+-----------+------------------+-------------+
> | Taro       | Yamada    |                2 |       46.98 |
> | Akiko      | Watanabe  |                1 |       45.96 |
> | Hanako     | Suzuki    |                2 |       41.45 |
> | Ryo        | Kobayashi |                1 |       35.46 |
> | Mika       | Ito       |                1 |       27.47 |
> | Yuki       | Sato      |                1 |       12.50 |
> | Kenji      | Takahashi |                1 |        9.80 |
> | Ken        | Tanaka    |                1 |        8.90 |
> +------------+-----------+------------------+-------------+

[root@drbd101 ~]# # Most popular products
[root@drbd101 ~]# mysql --defaults-extra-file=/root/.my.cnf -D grocery_store -e "
SELECT
    p.product_name,
    cat.category_name,
    SUM(td.quantity) AS total_sold,
    SUM(td.subtotal) AS total_revenue
FROM transaction_details td
JOIN products p ON td.product_id = p.product_id
JOIN categories cat ON p.category_id = cat.category_id
GROUP BY td.product_id
ORDER BY total_sold DESC
LIMIT 10;
"
> +---------------------+---------------+------------+---------------+
> | product_name        | category_name | total_sold | total_revenue |
> +---------------------+---------------+------------+---------------+
> | Tomato              | Vegetables    |          7 |          5.60 |
> | Apple (Fuji)        | Fruits        |          7 |         10.50 |
> | Banana              | Fruits        |          6 |          1.80 |
> | Green Tea 500ml     | Beverages     |          6 |          9.00 |
> | Chicken Breast 500g | Meat          |          5 |         29.95 |
> | Carrot              | Vegetables    |          5 |          2.50 |
> | Mineral Water 500ml | Beverages     |          5 |          4.95 |
> | Cucumber            | Vegetables    |          5 |          3.00 |
> | Yogurt (Plain)      | Dairy         |          4 |          7.20 |
> | Whole Milk 1L       | Dairy         |          4 |         10.00 |
> +---------------------+---------------+------------+---------------+

[root@drbd101 ~]# # Daily sales summary
[root@drbd101 ~]# mysql --defaults-extra-file=/root/.my.cnf -D grocery_store -e "
SELECT
    DATE(t.transaction_date) AS sale_date,
    COUNT(DISTINCT t.transaction_id) AS num_transactions,
    SUM(t.total_amount) AS daily_total
FROM transactions t
GROUP BY DATE(t.transaction_date)
ORDER BY sale_date;
"
> +------------+------------------+-------------+
> | sale_date  | num_transactions | daily_total |
> +------------+------------------+-------------+
> | 2026-03-10 |                3 |       46.67 |
> | 2026-03-11 |                2 |       44.18 |
> | 2026-03-12 |                2 |       55.76 |
> | 2026-03-13 |                2 |       46.45 |
> | 2026-03-14 |                1 |       35.46 |
> +------------+------------------+-------------+

```

# Add STONITH
## Avilable agents
| Fencing Method       | Requires                   | Reliability                  |
|----------------------|----------------------------|------------------------------|
| fence_virsh          | KVM hypervisor SSH access  | ✅ High                     |
| fence_ipmilan        | IPMI/BMC hardware          | ✅ High                     |
| fence_sbd (watchdog) | Software/hardware watchdog | ✅ Medium-High              |
| No STONITH           | Nothing                    | ❌ Manual recovery required |

// Snapshot init_cluster (Test failover and recovery)

* README_fence_virsh.md
* README_fence_sbd.md

// Snapshot init_fence_sbd (Test SBD fencing)

* README_upgrade_mariadb.md

// ...existing code...
| Command                                                        | Description                                              |
|----------------------------------------------------------------|----------------------------------------------------------|
| crm_mon -1                                                     | One-shot cluster monitor                                 |
| crm_mon -Af1                                                   | Detailed cluster monitor                                 |
| cibadmin --query --scope resources                             | List all resources                                       |
| crm_standby --node <node> --attr-value on                      | Put node in standby                                      |
| crm_standby --node <node> --attr-value off                     | Remove node from standby                                 |
| crm_resource --move --resource grp_mariadb --node <node>       | Move resource group to node                              |
|                                                                | We can also specify svc_mariadb which is in grp_mariadb. |
| crm_resource --clear --resource grp_mariadb                    | Clear resource constraints                               |
|                                                                | We can also specify svc_mariadb which is in grp_mariadb. |
| crm_resource --cleanup                                         | Clear failed actions                                     |
| drbdadm status mariadb                                         | DRBD replication status                                  |
| stonith_admin --fence <node>                                   | Manually fence a node                                    |
| stonith_admin --list-registered                                | List STONITH devices                                     |
| crm_attribute --type crm_config --name stonith-enabled --query | Check STONITH status                                     |

