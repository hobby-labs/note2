# Oracle Database XE Installation on CentOS 7.9

## Purpose
Create a development environment with Oracle DB XE to simulate migration from Oracle DB to MariaDB.

## Nodes

| Servers   | SSH/Internet<br>10.1.0.0/24<br>eth0 | Service<br>10.1.0.0/24<br>eth1 | Heartbeat1<br>10.1.1.0/24<br>eth2 | Heartbeat2<br>10.1.2.0/24<br>eth3 | DRBD Data sync<br>10.1.3.0/24<br>eth4 |
|-----------|-------------------------------------|--------------------------------|-----------------------------------|-----------------------------------|---------------------------------------|
| oracle101 | 172.31.101.111                      | 10.1.0.111                     | 10.1.1.111                        | 10.1.2.111                        | 10.1.3.111                            |
| oracle102 | 172.31.101.112                      | 10.1.0.112                     | 10.1.1.112                        | 10.1.2.112                        | 10.1.3.112                            |
| oracle103 | 172.31.101.113                      | 10.1.0.113                     | 10.1.1.113                        | 10.1.2.113                        | 10.1.3.113                            |

```
[root@oracle101 ~]# cat << EOF >> /etc/hosts
172.31.101.111 oracle101
172.31.101.112 oracle102
172.31.101.113 oracle103
EOF
```

## Prerequisites

### System Requirements
- CentOS 7.9 (x86_64)
- At least 2 GB RAM (4 GB recommended)
- At least 15 GB free disk space
- Swap space: at least 2 GB

### Check your system
```bash
cat /etc/centos-release
free -h
df -h
swapon --show
```

## Installation Steps

### Step 1: Install Required Packages
```bash
sudo yum install -y bc binutils compat-libcap1 compat-libstdc++-33 \
  glibc glibc-devel ksh libaio libaio-devel libX11 libXau libXi \
  libXtst libgcc libstdc++ libstdc++-devel libxcb make \
  smartmontools sysstat net-tools openssl
```

### Step 2: Download Oracle Database XE RPM

> **Note:** Oracle Database 21c XE is the latest version that supports CentOS 7.
> Oracle Database 23ai XE requires Oracle Linux 8/9 or RHEL 8/9.

Go to the Oracle download page and download the RPM:
- URL: https://www.oracle.com/database/technologies/xe-downloads.html
- Download: `oracle-database-xe-21c-1.0-1.ol7.x86_64.rpm`

Or use `wget` if you have the direct link (requires Oracle account acceptance):
```bash
# Download the preinstall RPM and the XE RPM
# The preinstall RPM automatically configures OS users, groups, kernel parameters, etc.
cd /tmp
```

### Step 3: Install the Oracle XE Preinstall Package
```bash
# Install the preinstall package (sets up oracle user, groups, kernel params)
sudo curl -o oracle-database-preinstall-21c-1.0-1.el7.x86_64.rpm \
  https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-21c-1.0-1.el7.x86_64.rpm

sudo yum -y localinstall oracle-database-preinstall-21c-1.0-1.el7.x86_64.rpm
```

### Step 4: Install Oracle Database XE
```bash
sudo yum -y localinstall /tmp/oracle-database-xe-21c-1.0-1.ol7.x86_64.rpm
```

```bash
rm -f oracle-database-preinstall-21c-1.0-1.el7.x86_64.rpm /tmp/oracle-database-xe-21c-1.0-1.ol7.x86_64.rpm
```

This will take several minutes. The RPM installs the software to `/opt/oracle`.

### Step 5: Configure the Database
```bash
sudo /etc/init.d/oracle-xe-21c configure
```

You will be prompted to set:
- **SYS and SYSTEM password** — choose a strong password and remember it!
// Use password below only in development environments, never in production!
// Secret1234

This step creates the database instance (XE) and may take 10-20 minutes.

### Step 6: Set Up Environment Variables

Add the following to the `oracle` user's profile:

```bash
# Switch to oracle user
sudo su - oracle

# Add to ~/.bash_profile
cat >> ~/.bash_profile << 'EOF'

# Oracle Environment
export ORACLE_HOME=/opt/oracle/product/21c/dbhomeXE
export ORACLE_SID=XE
export ORACLE_BASE=/opt/oracle
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
EOF

# Load the environment
source ~/.bash_profile
```

### Step 7: Verify the Installation

```bash
# As oracle user
sqlplus / as sysdba

# In SQL*Plus, run:
SQL> SELECT instance_name, status, version FROM v$instance;
SQL> SELECT banner FROM v$version;
SQL> EXIT;
```

### Step 8: Configure Firewall (if needed)

```bash
# Open Oracle listener port
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --reload
```

### Step 9: Enable Auto-Start on Boot

```bash
sudo systemctl daemon-reload
sudo systemctl enable oracle-xe-21c
```

### Step 10: Basic Service Management

```bash
# Start the database
sudo systemctl start oracle-xe-21c

# Stop the database
sudo systemctl stop oracle-xe-21c

# Check status
sudo systemctl status oracle-xe-21c
```

## Connection Information

| Property       | Value                        |
|----------------|------------------------------|
| Hostname       | localhost                    |
| Port           | 1521                         |
| SID            | XE                           |
| Service Name   | XEPDB1 (Pluggable DB)       |
| CDB Service    | XE (Container DB)           |
| EM Express URL | https://localhost:5500/em    |

### Connect with SQL*Plus
```bash
# Connect as SYSDBA
sqlplus / as sysdba

# Connect as SYSTEM
sqlplus system/Secret1234@localhost:1521/XE

# Connect to the Pluggable Database
sqlplus system/Secret1234@localhost:1521/XEPDB1
```

## Troubleshooting

### Check Listener Status
```bash
lsnrctl status
```

### Check Alert Log
```bash
tail -100 /opt/oracle/diag/rdbms/xe/XE/trace/alert_XE.log
```

### If Swap is Insufficient
```bash
# Create a 2GB swap file
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

## XE Limitations (21c)
- Up to 2 CPU threads
- Up to 2 GB RAM usage
- Up to 12 GB user data storage
- Single Pluggable Database (PDB) only
- No RAC, Data Guard, or partitioning