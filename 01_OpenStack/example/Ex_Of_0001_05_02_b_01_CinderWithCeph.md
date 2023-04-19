```
dev-storage01 # ssh-keygen -q -N "" -f ~/.ssh/ceph_cluster
dev-storage01 # cp ~/.ssh/ceph_cluster.pub ~/.ssh/authorized_keys
dev-storage01 # chmod 600 ~/.ssh/*
```

```
for target in dev-storage02 dev-storage03 dev-storage04 dev-storage05 dev-storage06 dev-storage07 dev-storage08 dev-compute01 dev-compute02; do
    echo "target => ${target}"
    ssh dev-storage01 -- sudo cat /root/.ssh/ceph_cluster | ssh ${target} -- sudo bash -c "cat - | sudo tee /root/.ssh/ceph_cluster > /dev/null"
    ssh dev-storage01 -- sudo cat /root/.ssh/ceph_cluster.pub | ssh ${target} -- sudo bash -c "cat - | sudo tee /root/.ssh/ceph_cluster.pub > /dev/null"
    ssh dev-storage01 -- sudo cat /root/.ssh/authorized_keys | ssh ${target} -- sudo bash -c "cat - | sudo tee /root/.ssh/authorized_keys > /dev/null"
    ssh ${target} -- sudo chmod 600 /root/.ssh/{ceph_cluster,ceph_cluster.pub,authorized_keys}
done
```

* ~/.ssh/config @ dev-storage01
```
dev-storage01 # cat << EOF > ~/.ssh/config
Host dev-storage* dev-storage*.openstack.example.com dev-compute* dev-compute*.openstack.example.com
    PreferredAuthentications publickey
    User root
    IdentityFile ~/.ssh/ceph_cluster
EOF

dev-storage01 # chmod 600 ~/.ssh/config
```

```
dev-storage01 # for node in dev-storage02 dev-storage03 dev-storage04 dev-storage05 dev-storage06 dev-storage07 dev-storage08 dev-compute01 dev-compute02; do
    scp -i ~/.ssh/ceph_cluster ~/.ssh/config ${node}:.ssh/config
    ssh -i ~/.ssh/ceph_cluster ${node} -- chmod 600 .ssh/config
done
```

// Snapshot created_ssh_keys

* dev-storage01
```
dev-storage01 # for node in dev-storage01 dev-storage02 dev-storage03 dev-storage04 dev-storage05 dev-storage06 dev-storage07 dev-storage08
do
    ssh ${node} "apt update; apt -y install ceph"
done
```

```
dev-storage01 # uuidgen
8e43f88e-7af8-47b4-b952-3f870ea53676
```

* /etc/ceph/ceph.conf @ dev-storage01 (Cluster name "ceph")
```
[global]
# specify cluster network for monitoring
cluster network = 172.22.0.0/16
# specify public network
public network = 172.22.0.0/16

# specify UUID genarated above
fsid = 8e43f88e-7af8-47b4-b952-3f870ea53676
# specify IP address of Monitor Daemon
mon host = 172.22.1.101
# specify Hostname of Monitor Daemon
mon initial members = dev-storage01
osd pool default crush rule = -1

# mon.(Node name)
[mon.dev-storage01]
# specify Hostname of Monitor Daemon
host = dev-storage01
# specify IP address of Monitor Daemon
mon addr = 172.22.1.101
# allow to delete pools
mon allow pool delete = true
```

```
dev-storage01 # ceph-authtool --create-keyring /etc/ceph/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
```

```
dev-storage01 # ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
```

```
dev-storage01 # ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd' --cap mgr 'allow r'
```

```
dev-storage01 # ceph-authtool /etc/ceph/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
dev-storage01 # ceph-authtool /etc/ceph/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring
```

// Snapshot imported_generated_keys

* dev-storage01
```
FSID=$(grep "^fsid" /etc/ceph/ceph.conf | awk {'print $NF'})
NODENAME=$(grep "^mon initial" /etc/ceph/ceph.conf | awk {'print $NF'})
NODEIP=$(grep "^mon host" /etc/ceph/ceph.conf | awk {'print $NF'})
echo "Debug. FSID=${FSID}, NODENAME=${NODENAME}, NODEIP=${NODEIP}"
monmaptool --create --add $NODENAME $NODEIP --fsid $FSID /etc/ceph/monmap
```

```
dev-storage01 # mkdir /var/lib/ceph/mon/ceph-${NODENAME}
```

```
ceph-mon --cluster ceph --mkfs -i $NODENAME --monmap /etc/ceph/monmap --keyring /etc/ceph/ceph.mon.keyring
chown ceph. /etc/ceph/ceph.*
chown -R ceph. /var/lib/ceph/mon/ceph-${NODENAME} /var/lib/ceph/bootstrap-osd
systemctl enable --now ceph-mon@${NODENAME}
```

```
dev-storage01 # ceph mon enable-msgr2
dev-storage01 # ceph config set mon auth_allow_insecure_global_id_reclaim false
```

```
dev-storage01 # ceph mgr module enable pg_autoscaler
```

```
dev-storage01 # mkdir /var/lib/ceph/mgr/ceph-${NODENAME}
```

* dev-storage01
```
dev-storage01 # ceph auth get-or-create mgr.${NODENAME} mon 'allow profile mgr' osd 'allow *' mds 'allow *'
[mgr.dev-storage01]
        key = AQBXiTtkhXrCBRAAR09DBUjk97/17npklZ8Xcg==
```

```
ceph auth get-or-create mgr.${NODENAME} | tee /etc/ceph/ceph.mgr.admin.keyring
cp /etc/ceph/ceph.mgr.admin.keyring /var/lib/ceph/mgr/ceph-${NODENAME}/keyring
chown ceph. /etc/ceph/ceph.mgr.admin.keyring
chown -R ceph. /var/lib/ceph/mgr/ceph-${NODENAME}
systemctl enable --now ceph-mgr@${NODENAME}
```

```
dev-storage01 # ceph osd lspools
1 .mgr

dev-storage01 # ceph -s
  cluster:
    id:     ffffffff-ffff-ffff-ffff-ffffffffffff
    health: HEALTH_OK

  services:
    mon: 1 daemons, quorum dev-storage01 (age 12m)
    mgr: dev-storage01(active, since 12s)
    osd: 0 osds: 0 up, 0 in

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:

dev-storage01 # ceph osd tree
ID  CLASS  WEIGHT  TYPE NAME     STATUS  REWEIGHT  PRI-AFF
-1              0  root default
root@dev-storage01:~# ceph df
--- RAW STORAGE ---
CLASS  SIZE  AVAIL  USED  RAW USED  %RAW USED
TOTAL   0 B    0 B   0 B       0 B          0

--- POOLS ---
POOL  ID  PGS  STORED  OBJECTS  USED  %USED  MAX AVAIL

dev-storage01 # ceph osd df
ID  CLASS  WEIGHT  REWEIGHT  SIZE  RAW USE  DATA  OMAP  META  AVAIL  %USE  VAR  PGS  STATUS
                      TOTAL   0 B      0 B   0 B   0 B   0 B    0 B     0
MIN/MAX VAR: -/-  STDDEV: 0
```

// Snapshot configure_ceph_manager_mon_node

* dev-storage01

```
#!/usr/bin/env bash

for node_index in {1..8}; do
    node=$(printf "dev-storage%02d" ${node_index})

    if [ ! ${node} = "dev-storage01" ]; then
        scp /etc/ceph/ceph.conf ${node}:/etc/ceph/ceph.conf
        scp /etc/ceph/ceph.client.admin.keyring ${node}:/etc/ceph
        scp /var/lib/ceph/bootstrap-osd/ceph.keyring ${node}:/var/lib/ceph/bootstrap-osd
    fi

    ssh $node << 'EOF'
        chown ceph. /etc/ceph/ceph.* /var/lib/ceph/bootstrap-osd/*

        for drive_letter_index in d e f g; do
            parted --script /dev/vd${drive_letter_index} 'mklabel gpt'
            parted --script /dev/vd${drive_letter_index} "mkpart primary 0% 100%"
            count=0
            while [ ${count} -lt 30 ]; do
                echo "$(date) - ${HOSTNAME} - INFO: Creating a ceph volume at /dev/vd${drive_letter_index}1 on $(uname -n)"
                ceph-volume lvm create --data /dev/vd${drive_letter_index}1
                ceph-volume lvm list
                vg_name=$(pvdisplay /dev/vd${drive_letter_index}1 | grep -P "^ *VG Name *ceph\-.*\$" | grep -o '[^ ]*$')
                if [[ "${vg_name}" =~ ^ceph\-.*$ ]]; then
                    echo "$(date) - ${HOSTNAME} - INFO: Volume group for Ceph has found. vg_name=${vg_name}."
                    break
                fi
                (( ++count ))
                echo "$(date) - ${HOSTNAME} - ERROR: Failed to create ceph volume(Obtained vg_name=${vg_name}). Retrying to execute it agin (count=${count})." >&2
                sleep 5
            done
        done
EOF
done
```

```
dev-storage01 # ceph -s
  cluster:
    id:     8e43f88e-7af8-47b4-b952-3f870ea53676
    health: HEALTH_OK

  services:
    mon: 1 daemons, quorum dev-storage01 (age 8m)
    mgr: dev-storage01(active, since 8m)
    osd: 32 osds: 32 up (since 3m), 32 in (since 3m)

  data:
    pools:   1 pools, 1 pgs
    objects: 2 objects, 449 KiB
    usage:   1.1 GiB used, 255 GiB / 256 GiB avail
    pgs:     1 active+clean

# ceph osd tree
ID   CLASS  WEIGHT   TYPE NAME               STATUS  REWEIGHT  PRI-AFF
 -1         0.24951  root default
 -3         0.03119      host dev-storage01
  0    hdd  0.00780          osd.0               up   1.00000  1.00000
  1    hdd  0.00780          osd.1               up   1.00000  1.00000
  2    hdd  0.00780          osd.2               up   1.00000  1.00000
  3    hdd  0.00780          osd.3               up   1.00000  1.00000
 -5         0.03119      host dev-storage02
  4    hdd  0.00780          osd.4               up   1.00000  1.00000
  5    hdd  0.00780          osd.5               up   1.00000  1.00000
  6    hdd  0.00780          osd.6               up   1.00000  1.00000
  7    hdd  0.00780          osd.7               up   1.00000  1.00000
 -7         0.03119      host dev-storage03
  8    hdd  0.00780          osd.8               up   1.00000  1.00000
  9    hdd  0.00780          osd.9               up   1.00000  1.00000
 10    hdd  0.00780          osd.10              up   1.00000  1.00000
 11    hdd  0.00780          osd.11              up   1.00000  1.00000
 -9         0.03119      host dev-storage04
 12    hdd  0.00780          osd.12              up   1.00000  1.00000
 13    hdd  0.00780          osd.13              up   1.00000  1.00000
 14    hdd  0.00780          osd.14              up   1.00000  1.00000
 15    hdd  0.00780          osd.15              up   1.00000  1.00000
-11         0.03119      host dev-storage05
 16    hdd  0.00780          osd.16              up   1.00000  1.00000
 17    hdd  0.00780          osd.17              up   1.00000  1.00000
 18    hdd  0.00780          osd.18              up   1.00000  1.00000
 19    hdd  0.00780          osd.19              up   1.00000  1.00000
-13         0.03119      host dev-storage06
 20    hdd  0.00780          osd.20              up   1.00000  1.00000
 21    hdd  0.00780          osd.21              up   1.00000  1.00000
 22    hdd  0.00780          osd.22              up   1.00000  1.00000
 23    hdd  0.00780          osd.23              up   1.00000  1.00000
-15         0.03119      host dev-storage07
 24    hdd  0.00780          osd.24              up   1.00000  1.00000
 25    hdd  0.00780          osd.25              up   1.00000  1.00000
 26    hdd  0.00780          osd.26              up   1.00000  1.00000
 27    hdd  0.00780          osd.27              up   1.00000  1.00000
-17         0.03119      host dev-storage08
 28    hdd  0.00780          osd.28              up   1.00000  1.00000
 29    hdd  0.00780          osd.29              up   1.00000  1.00000
 30    hdd  0.00780          osd.30              up   1.00000  1.00000
 31    hdd  0.00780          osd.31              up   1.00000  1.00000

dev-storage01 # ceph df
--- RAW STORAGE ---
CLASS     SIZE    AVAIL     USED  RAW USED  %RAW USED
hdd    256 GiB  255 GiB  1.1 GiB   1.1 GiB       0.44
TOTAL  256 GiB  255 GiB  1.1 GiB   1.1 GiB       0.44

--- POOLS ---
POOL  ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
.mgr   1    1  449 KiB        2  449 KiB      0     77 GiB

dev-storage01 # ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE     RAW USE  DATA     OMAP  META     AVAIL    %USE  VAR    PGS  STATUS
 0    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
 1    hdd  0.00780   1.00000  8.0 GiB   25 MiB  2.0 MiB   0 B   23 MiB  8.0 GiB  0.30   0.68    0      up
 2    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
 3    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
 4    hdd  0.00780   1.00000  8.0 GiB   25 MiB  2.0 MiB   0 B   23 MiB  8.0 GiB  0.30   0.68    0      up
 5    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
 6    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.5 MiB   0 B   22 MiB  8.0 GiB  0.30   0.68    1      up
 7    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
 8    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
 9    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
10    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
11    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.5 MiB   0 B   22 MiB  8.0 GiB  0.30   0.67    1      up
12    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.66    0      up
13    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.5 MiB   0 B   22 MiB  8.0 GiB  0.30   0.67    1      up
14    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.65    0      up
15    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.65    0      up
16    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.65    0      up
17    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.65    0      up
18    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.65    0      up
19    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.65    0      up
20    hdd  0.00780   1.00000  8.0 GiB   24 MiB  2.0 MiB   0 B   22 MiB  8.0 GiB  0.29   0.65    0      up
21    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.29   0.65    0      up
22    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.29   0.65    0      up
23    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.29   0.65    0      up
24    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.29   0.65    0      up
25    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.29   0.64    0      up
26    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.29   0.64    0      up
27    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.28   0.64    0      up
28    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.28   0.64    0      up
29    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.28   0.64    0      up
30    hdd  0.00780   1.00000  8.0 GiB   23 MiB  2.0 MiB   0 B   21 MiB  8.0 GiB  0.28   0.64    0      up
31    hdd  0.00780   1.00000  8.0 GiB  423 MiB  2.0 MiB   0 B   21 MiB  7.6 GiB  5.17  11.68    0      up
                       TOTAL  256 GiB  1.1 GiB   66 MiB   0 B  693 MiB  255 GiB  0.44
MIN/MAX VAR: 0.64/11.68  STDDEV: 0.85
```

```
dev-storage01 # for node in dev-compute01 dev-compute02; do
    ssh ${node} "apt -y install ceph-common"
    scp /etc/ceph/ceph.conf ${node}:/etc/ceph/

    scp /etc/ceph/ceph.client.admin.keyring ${node}:/etc/ceph/
    ssh ${node} "chown ceph. /etc/ceph/ceph.*"
done
```

// Snapshot installed_ceph_clients

