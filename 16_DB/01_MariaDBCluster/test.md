# Creating MySQL 5.1.73 HA Cluster on Ubuntu 24.04

## Architecture Overview

This setup creates a high-availability MySQL cluster using:
- **DRBD**: Distributed Replicated Block Device for disk replication
- **Corosync**: Cluster communication layer
- **Pacemaker**: Cluster resource manager
- **MySQL 5.1.73**: Database server (compiled from source)

## Prerequisites

| Servers       | Service          | SSH          | Heartbeat1   | Heartbeat2   | DRBD Data sync  |
|               | 172.25.101.0/24  | 10.1.0.0/24  | 10.1.1.0/24  | 10.1.2.0/24  | 10.1.3.0/24     |
|---------------|------------------|--------------|--------------|--------------|-----------------|
| stg-storage01 | 172.25.101.101   | 10.0.0.101   | 10.1.1.101   | 10.1.2.101   | 10.1.3.101      |
| stg-storage02 | 172.25.101.102   | 10.0.0.102   | 10.1.1.102   | 10.1.2.102   | 10.1.3.102      |
| stg-storage03 | 172.25.101.103   | 10.0.0.103   | 10.1.1.103   | 10.1.2.103   | 10.1.3.103      |

**Virtual IP**: 172.25.101.10 (for client connections)

**Requirements**:
- Ubuntu 24.04 on all nodes
- Root access on both nodes
- Additional disk `/dev/vdb` with partition `/dev/vdb1` for DRBD
- Network connectivity between nodes
- MySQL 5.1.73 source: `mysql-5.1.73.tar.gz`

## Installation Steps

### 1. Prepare Both Nodes (stg-storage01 and stg-storage02)

#### Update System and Install Dependencies

```bash
# On both nodes
apt update
apt upgrade -y

# Install build dependencies for MySQL 5.1.73
apt install -y build-essential cmake libncurses5-dev bison \
  libssl-dev pkg-config

# Install cluster packages
apt install -y drbd-utils pacemaker corosync pcs crmsh \
  resource-agents fence-agents

# Enable and start pcsd
systemctl enable pcsd
systemctl start pcsd
```

#### Configure Hosts File

```bash
# On both nodes - edit /etc/hosts
cat >> /etc/hosts <<EOF
172.25.101.11 stg-storage01
172.25.101.12 stg-storage02
10.0.0.11 stg-storage01-drbd
10.0.0.12 stg-storage02-drbd
EOF
```

#### Configure Firewall

```bash
# On both nodes
# Allow cluster communication
ufw allow from 172.25.101.0/24
ufw allow from 10.0.0.0/24

# Or disable firewall for testing
ufw disable
```

### 2. Compile and Install MySQL 5.1.73

#### Extract and Prepare Source

```bash
# On both nodes
cd /usr/local/src

# Copy mysql-5.1.73.tar.gz to this location
# Then extract
tar -zxf mysql-5.1.73.tar.gz
cd mysql-5.1.73
```

#### Apply Compatibility Patches for Modern Systems

MySQL 5.1.73 is very old and needs patches for Ubuntu 24.04:

```bash
# Create patch file for compilation issues
cat > mysql-5.1.73-ubuntu24.patch <<'PATCH'
--- a/include/my_global.h
+++ b/include/my_global.h
@@ -18,6 +18,10 @@
 #ifndef _global_h
 #define _global_h
 
+#if !defined(HAVE_BOOL) && defined(__cplusplus)
+#define HAVE_BOOL
+#endif
+
 #ifdef __CYGWIN__
 /* We use a Unix API, so pretend it's not Windows */
 #undef WIN
PATCH

# Apply patch
patch -p1 < mysql-5.1.73-ubuntu24.patch
```

#### Configure MySQL Build

```bash
# Configure with appropriate options
./configure \
  --prefix=/usr/local/mysql \
  --with-unix-socket-path=/var/lib/mysql/mysql.sock \
  --with-tcp-port=3306 \
  --enable-thread-safe-client \
  --with-mysqld-user=mysql \
  --with-extra-charsets=all \
  --enable-local-infile \
  --with-plugins=innobase \
  --with-ssl \
  CFLAGS="-O3" \
  CXXFLAGS="-O3 -felide-constructors -fno-exceptions -fno-rtti"

# Note: This may take 10-20 minutes
```

#### Compile and Install

```bash
# Compile (this will take 30-60 minutes)
make -j$(nproc)

# Install
make install

# Create mysql user and group
groupadd mysql
useradd -r -g mysql -s /bin/false mysql

# Set ownership
cd /usr/local/mysql
chown -R mysql:mysql .

# Create necessary directories
mkdir -p /var/lib/mysql
chown mysql:mysql /var/lib/mysql
chmod 755 /var/lib/mysql

# Setup environment
cat >> /etc/profile.d/mysql.sh <<'EOF'
export PATH=/usr/local/mysql/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/mysql/lib:$LD_LIBRARY_PATH
EOF

source /etc/profile.d/mysql.sh
```

#### Create MySQL Configuration

```bash
# On both nodes - create /etc/my.cnf
cat > /etc/my.cnf <<'EOF'
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
port=3306
user=mysql
pid-file=/var/lib/mysql/mysql.pid

# Binary logging
log-bin=mysql-bin
binlog_format=mixed
expire_logs_days=7

# Server ID (use 1 on stg-storage01, 2 on stg-storage02)
server-id=1

# InnoDB settings
innodb_buffer_pool_size=512M
innodb_log_file_size=128M
innodb_log_buffer_size=8M
innodb_flush_log_at_trx_commit=2
innodb_file_per_table=1

# Connection settings
max_connections=200
wait_timeout=28800
interactive_timeout=28800

# Character set
character-set-server=utf8
collation-server=utf8_general_ci

# Logging
log-error=/var/log/mysql/error.log
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow.log
long_query_time=2

[mysqld_safe]
log-error=/var/log/mysql/error.log
pid-file=/var/lib/mysql/mysql.pid

[client]
socket=/var/lib/mysql/mysql.sock
port=3306

[mysql]
no-auto-rehash
EOF

# Create log directory
mkdir -p /var/log/mysql
chown mysql:mysql /var/log/mysql

# IMPORTANT: On stg-storage02, change server-id to 2
# Edit /etc/my.cnf on stg-storage02:
# server-id=2
```

#### Create MySQL Startup Script

```bash
# On both nodes
cat > /etc/systemd/system/mysql.service <<'EOF'
[Unit]
Description=MySQL 5.1.73 Server
After=network.target

[Service]
Type=forking
User=mysql
Group=mysql
ExecStart=/usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf
ExecStop=/bin/kill -TERM $MAINPID
Restart=on-failure
RestartSec=5s
PIDFile=/var/lib/mysql/mysql.pid

[Install]
WantedBy=multi-user.target
EOF

# DO NOT enable or start MySQL service yet
# Pacemaker will manage it
```

### 3. Configure DRBD

#### Install DRBD Kernel Module

```bash
# On both nodes
modprobe drbd

# Load on boot
echo "drbd" >> /etc/modules-load.d/drbd.conf
```

#### Create DRBD Resource Configuration

```bash
# On both nodes - create /etc/drbd.d/mysql.res
cat > /etc/drbd.d/mysql.res <<'EOF'
resource mysql {
  protocol C;
  
  startup {
    wfc-timeout 15;
    degr-wfc-timeout 60;
  }
  
  disk {
    on-io-error detach;
  }
  
  net {
    cram-hmac-alg sha1;
    shared-secret "MySQLHA2025Ubuntu";
    after-sb-0pri discard-zero-changes;
    after-sb-1pri discard-secondary;
    after-sb-2pri disconnect;
    max-buffers 8192;
    max-epoch-size 8192;
  }
  
  syncer {
    rate 100M;
    verify-alg sha1;
  }
  
  on stg-storage01 {
    device /dev/drbd0;
    disk /dev/vdb1;
    address 10.0.0.11:7788;
    meta-disk internal;
  }
  
  on stg-storage02 {
    device /dev/drbd0;
    disk /dev/vdb1;
    address 10.0.0.12:7788;
    meta-disk internal;
  }
}
EOF
```

#### Initialize and Start DRBD

```bash
# On both nodes - create metadata
drbdadm create-md mysql

# On both nodes - bring up DRBD resource
drbdadm up mysql

# Check status (should show "Inconsistent/Inconsistent")
drbdadm status

# On PRIMARY node (stg-storage01) only - force primary and start initial sync
drbdadm primary --force mysql

# Monitor sync progress (may take time depending on disk size)
watch -n 2 'cat /proc/drbd'
# Wait until sync shows "UpToDate/UpToDate"
```

#### Format and Initialize MySQL Data on DRBD

```bash
# On PRIMARY node (stg-storage01) only, after sync completes

# Format DRBD device
mkfs.ext4 /dev/drbd0

# Mount temporarily
mount /dev/drbd0 /var/lib/mysql
chown mysql:mysql /var/lib/mysql
chmod 755 /var/lib/mysql

# Initialize MySQL database
cd /usr/local/mysql
./scripts/mysql_install_db \
  --user=mysql \
  --basedir=/usr/local/mysql \
  --datadir=/var/lib/mysql

# Start MySQL temporarily to secure it
/usr/local/mysql/bin/mysqld_safe --user=mysql &

# Wait for MySQL to start
sleep 10

# Secure MySQL installation
/usr/local/mysql/bin/mysql_secure_installation
# Set root password
# Remove anonymous users: Y
# Disallow root login remotely: Y
# Remove test database: Y
# Reload privilege tables: Y

# Create a test database
/usr/local/mysql/bin/mysql -u root -p <<'SQL'
CREATE DATABASE testdb;
USE testdb;
CREATE TABLE test (id INT AUTO_INCREMENT PRIMARY KEY, data VARCHAR(100));
INSERT INTO test (data) VALUES ('Initial data from storage01');
SQL

# Stop MySQL
killall mysqld
sleep 5

# Unmount - Pacemaker will manage this
umount /var/lib/mysql

# Demote to secondary
drbdadm secondary mysql
```

### 4. Configure Corosync and Pacemaker

#### Set Password for hacluster User

```bash
# On both nodes
echo "hacluster:your-secure-password" | chpasswd
```

#### Authenticate Cluster Nodes

```bash
# On PRIMARY node (stg-storage01)
pcs host auth stg-storage01 stg-storage02 \
  -u hacluster \
  -p your-secure-password
```

#### Create and Start Cluster

```bash
# On PRIMARY node (stg-storage01)
pcs cluster setup mysql_cluster \
  stg-storage01 addr=172.25.101.11 \
  stg-storage02 addr=172.25.101.12

# Start cluster on both nodes
pcs cluster start --all

# Enable cluster to start on boot
pcs cluster enable --all

# Check cluster status
pcs status
```

#### Configure Cluster Properties

```bash
# On PRIMARY node

# Disable STONITH (if no fencing device available)
pcs property set stonith-enabled=false

# Set quorum policy for 2-node cluster
pcs property set no-quorum-policy=ignore

# Set default resource stickiness
pcs resource defaults update resource-stickiness=200

# Disable concurrent fencing
pcs property set concurrent-fencing=false
```

### 5. Create Cluster Resources

#### Create DRBD Promotable Clone Resource

```bash
# On PRIMARY node

# Create DRBD resource
pcs resource create drbd_mysql ocf:linbit:drbd \
  drbd_resource=mysql \
  op monitor interval=29s role=Promoted \
  op monitor interval=31s role=Unpromoted

# Create promotable clone (master/slave)
pcs resource promotable drbd_mysql \
  promoted-max=1 \
  promoted-node-max=1 \
  clone-max=2 \
  clone-node-max=1 \
  notify=true

# Check status
pcs status
```

#### Create Filesystem Resource

```bash
# Create filesystem resource
pcs resource create fs_mysql Filesystem \
  device=/dev/drbd0 \
  directory=/var/lib/mysql \
  fstype=ext4 \
  options=noatime,nodiratime \
  op monitor interval=20s timeout=40s \
  op start timeout=60s \
  op stop timeout=60s

# Add colocation constraint - filesystem runs on promoted DRBD
pcs constraint colocation add fs_mysql \
  with drbd_mysql-clone INFINITY with-rsc-role=Master

# Add order constraint - promote DRBD before starting filesystem
pcs constraint order promote drbd_mysql-clone \
  then start fs_mysql
```

#### Create Virtual IP Resource

```bash
# Create virtual IP
pcs resource create vip_mysql IPaddr2 \
  ip=172.25.101.10 \
  cidr_netmask=24 \
  nic=ens3 \
  op monitor interval=30s

# Colocation: VIP with filesystem
pcs constraint colocation add vip_mysql with fs_mysql INFINITY

# Order: filesystem before VIP
pcs constraint order fs_mysql then vip_mysql
```

#### Create MySQL Service Resource

```bash
# Create custom MySQL OCF resource agent
cat > /usr/lib/ocf/resource.d/heartbeat/mysql-custom <<'EOF'
#!/bin/bash
#
# MySQL OCF RA for MySQL 5.1.73 compiled from source
#

: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/lib/heartbeat}
. ${OCF_FUNCTIONS_DIR}/ocf-shellfuncs

MYSQL_BINDIR="/usr/local/mysql/bin"
MYSQL_DATADIR="/var/lib/mysql"
MYSQL_PIDFILE="/var/lib/mysql/mysql.pid"
MYSQL_SOCKET="/var/lib/mysql/mysql.sock"

mysql_start() {
    if mysql_monitor; then
        ocf_log info "MySQL already running"
        return $OCF_SUCCESS
    fi
    
    ${MYSQL_BINDIR}/mysqld_safe --defaults-file=/etc/my.cnf &
    
    # Wait for MySQL to start
    count=0
    while [ $count -lt 30 ]; do
        if mysql_monitor; then
            ocf_log info "MySQL started successfully"
            return $OCF_SUCCESS
        fi
        sleep 1
        count=$((count + 1))
    done
    
    ocf_log err "MySQL failed to start"
    return $OCF_ERR_GENERIC
}

mysql_stop() {
    if ! mysql_monitor; then
        ocf_log info "MySQL already stopped"
        return $OCF_SUCCESS
    fi
    
    if [ -f "$MYSQL_PIDFILE" ]; then
        pid=$(cat $MYSQL_PIDFILE)
        kill $pid
        
        count=0
        while [ $count -lt 30 ]; do
            if ! mysql_monitor; then
                ocf_log info "MySQL stopped successfully"
                return $OCF_SUCCESS
            fi
            sleep 1
            count=$((count + 1))
        done
        
        # Force kill if still running
        kill -9 $pid 2>/dev/null
    fi
    
    return $OCF_SUCCESS
}

mysql_monitor() {
    if [ -f "$MYSQL_PIDFILE" ]; then
        pid=$(cat $MYSQL_PIDFILE)
        if ps -p $pid > /dev/null 2>&1; then
            if [ -S "$MYSQL_SOCKET" ]; then
                ${MYSQL_BINDIR}/mysqladmin --socket=$MYSQL_SOCKET ping > /dev/null 2>&1
                return $?
            fi
        fi
    fi
    return $OCF_NOT_RUNNING
}

case $__OCF_ACTION in
    start)
        mysql_start
        ;;
    stop)
        mysql_stop
        ;;
    monitor)
        mysql_monitor
        ;;
    meta-data)
        cat <<END
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="mysql-custom">
<version>1.0</version>
<shortdesc lang="en">MySQL 5.1.73 custom</shortdesc>
</resource-agent>
END
        exit $OCF_SUCCESS
        ;;
    *)
        exit $OCF_ERR_UNIMPLEMENTED
        ;;
esac
EOF

chmod +x /usr/lib/ocf/resource.d/heartbeat/mysql-custom

# Create MySQL resource
pcs resource create mysql_service ocf:heartbeat:mysql-custom \
  op start timeout=120s \
  op stop timeout=120s \
  op monitor interval=20s timeout=30s

# Colocation: MySQL with VIP
pcs constraint colocation add mysql_service with vip_mysql INFINITY

# Order: VIP before MySQL
pcs constraint order vip_mysql then mysql_service
```

### 6. Verification and Testing

#### Check Cluster Status

```bash
# Overall status
pcs status

# Should show all resources running on one node
# Expected output:
#  * drbd_mysql-clone (promotable): Master on stg-storage01
#  * fs_mysql: Started on stg-storage01
#  * vip_mysql: Started on stg-storage01
#  * mysql_service: Started on stg-storage01

# DRBD status
cat /proc/drbd
drbdadm status

# Check which node is active
ip addr show | grep 172.25.101.10
```

#### Test MySQL Connection

```bash
# Connect via virtual IP
/usr/local/mysql/bin/mysql -h 172.25.101.10 -u root -p

# Check test database
USE testdb;
SELECT * FROM test;
INSERT INTO test (data) VALUES ('Testing cluster');
SELECT * FROM test;
```

#### Test Manual Failover

```bash
# Move resources to stg-storage02
pcs resource move mysql_service stg-storage02

# Wait and check status
sleep 10
pcs status

# Verify VIP moved
ip addr show | grep 172.25.101.10

# Connect and verify data
/usr/local/mysql/bin/mysql -h 172.25.101.10 -u root -p -e "SELECT * FROM testdb.test;"

# Clear constraint to allow automatic failback
pcs resource clear mysql_service
```

#### Test Automatic Failover (Node Failure)

```bash
# On stg-storage01, simulate node failure
pcs cluster stop stg-storage01

# On stg-storage02, watch resources migrate
watch -n 2 'pcs status'

# Test database access
/usr/local/mysql/bin/mysql -h 172.25.101.10 -u root -p -e "SELECT * FROM testdb.test;"

# Bring stg-storage01 back online
# (on stg-storage01)
pcs cluster start stg-storage01
```

## Monitoring and Maintenance

### Monitor Commands

```bash
# Real-time cluster status
crm_mon -Afr -1

# Watch DRBD
watch -n 2 'cat /proc/drbd'

# Check MySQL process
ps aux | grep mysql

# View cluster logs
tail -f /var/log/syslog | grep -E 'corosync|pacemaker'

# Check MySQL logs
tail -f /var/log/mysql/error.log
```

### Maintenance Mode

```bash
# Enter maintenance mode
pcs property set maintenance-mode=true

# Perform maintenance...
# You can manually start/stop resources

# Exit maintenance mode
pcs property set maintenance-mode=false
```

### Backup MySQL Data

```bash
# Put cluster in maintenance mode
pcs property set maintenance-mode=true

# On active node, backup MySQL
/usr/local/mysql/bin/mysqldump -u root -p --all-databases --single-transaction \
  > /backup/mysql-backup-$(date +%Y%m%d).sql

# Exit maintenance mode
pcs property set maintenance-mode=false
```

## Troubleshooting

### DRBD Issues

```bash
# Check DRBD status
drbdadm status
cat /proc/drbd

# If split-brain occurs:
# On node to discard:
drbdadm secondary mysql
drbdadm disconnect mysql
drbdadm -- --discard-my-data connect mysql

# On node to keep:
drbdadm connect mysql
```

### Cluster Issues

```bash
# Check corosync
corosync-cfgtool -s

# Check pacemaker
pcs status

# Restart cluster services
pcs cluster stop --all
pcs cluster start --all

# View constraints
pcs constraint show --full
```

### MySQL Issues

```bash
# Check if MySQL is running
pgrep -f mysqld

# Check socket
ls -l /var/lib/mysql/mysql.sock

# Test local connection
/usr/local/mysql/bin/mysql -u root -p -S /var/lib/mysql/mysql.sock

# Check error log
tail -100 /var/log/mysql/error.log
```

## Important Notes

- **MySQL 5.1.73 is VERY OLD** (released 2013, EOL 2013)
- Has **known security vulnerabilities** - DO NOT use in production
- No security patches available
- Consider MySQL 8.0 or MariaDB 10.11+ for production
- This setup is for **testing/learning purposes only**
- Always backup data before maintenance
- Test failover procedures regularly
- Monitor disk space on DRBD volumes

## Security Recommendations

Since you must use MySQL 5.1.73:
1. **Isolate the cluster** - Use private network only
2. **Firewall rules** - Block external access to MySQL port
3. **Strong passwords** - Use complex passwords
4. **Regular backups** - Automate daily backups
5. **Network encryption** - Consider VPN or SSH tunnels for remote access

## Next Steps

1. Configure MySQL users and permissions
2. Set up backup automation
3. Configure monitoring (Nagios, Zabbix, etc.)
4. Document runbooks for common scenarios
5. Practice failover procedures

## References

- [DRBD User's Guide](https://linbit.com/drbd-user-guide/)
- [Pacemaker Documentation](https://clusterlabs.org/pacemaker/doc/)
- [Ubuntu HA Guide](https://ubuntu.com/server/docs/clustering-introduction)
- [MySQL 5.1 Manual](https://dev.mysql.com/doc/refman/5.1/en/)