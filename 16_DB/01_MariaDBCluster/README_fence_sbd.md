# fence_sbd

* How Watchdog-Only SBD Works
```
Normal operation:
  SBD daemon runs on every node
  SBD keeps petting the watchdog timer every few seconds
  Watchdog stays happy → node stays alive

When fencing is triggered:
  SBD daemon stops petting the watchdog
  Watchdog timer expires
  → Hardware/kernel forces a reboot
  → Node is guaranteed offline
  → Surviving nodes proceed with failover
```

* drbd101, drbd102, drbd103 (all nodes)
```
# On ALL three nodes
yum install -y autoconf automake libtool
yum install -y libxml2-devel libuuid-devel

# Check headers are present
ls /usr/include/pacemaker/
ls /usr/include/corosync/

# On ALL three nodes
cd /usr/local/src
git clone https://github.com/ClusterLabs/sbd.git
cd sbd
git checkout v1.4.0   # or latest stable tag
autoreconf -fvi
./configure --prefix=/usr --sysconfdir=/etc
make -j$(nproc)
make install

which sbd
sbd -w /dev/watchdog query-watchdog

corosync -v
> Corosync Cluster Engine, version '3.1.0'
> Copyright (c) 2006-2018 Red Hat, Inc.

crm_mon --version
> Pacemaker 2.0.5
> Written by Andrew Beekhof

# Check which watchdog devices exist
ls -l /dev/watchdog*
> crw------- 1 root root  10, 130 Mar 11 13:29 /dev/watchdog
> crw------- 1 root root 250,   0 Mar 11 13:29 /dev/watchdog0

# If there is /dev/watchdog0, check the driver
# On ALL three nodes
rm -f /etc/modules-load.d/softdog.conf
modprobe -r softdog 2>/dev/null

cat /sys/class/watchdog/watchdog0/identity
> iTCO_wdt

# Configure SBD
cat > /etc/sysconfig/sbd << 'EOF'
SBD_PACEMAKER=yes
SBD_STARTMODE=always
SBD_DELAY_START=no
SBD_WATCHDOG_DEV=/dev/watchdog
SBD_WATCHDOG_TIMEOUT=10
SBD_OPTS="-w /dev/watchdog"
EOF
```

Test SBD Watchdog.
⚠️ This test will reboot the node. Run on one node at a time.

* drbd103
```
# Test with explicit device path
sbd -w /dev/watchdog test-watchdog
```

After reboot the system, continue remaining setups on all nodes.

* drbd101, drbd102, drbd103 (all nodes)
```
cat > /etc/systemd/system/sbd.service << 'EOF'
[Unit]
Description=Shared-storage based fencing daemon
Documentation=man:sbd(8)

[Service]
Type=forking
PIDFile=/var/run/sbd.pid
EnvironmentFile=/etc/sysconfig/sbd
ExecStart=/usr/sbin/sbd $SBD_OPTS -p /var/run/sbd.pid watch
GuessMainPID=no
TimeoutStartSec=10
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF

# Shutdown all nodes.
shutdown -r now
```

After reboot, check SBD status on all nodes.
```
systemctl status sbd
systemctl status pacemaker
systemctl status corosync
systemctl status drbd
crm_mon -1
```


```
# On drbd101(Primary) only
crm_attribute --type crm_config --name stonith-enabled --update true
crm_attribute --type crm_config --name stonith-watchdog-timeout --update 30
```

