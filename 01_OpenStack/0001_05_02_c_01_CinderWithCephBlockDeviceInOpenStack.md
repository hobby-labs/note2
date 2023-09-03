# Ceph for OpenStack
; Chapter 1. Ceph block devices and OpenStack
: https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/html/block_device_to_openstack_guide/ceph-block-devices-and-openstack-rbd-osp

; Chapter 2. Installing and configuring Ceph for OpenStack
: https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/html/block_device_to_openstack_guide/installing-and-configuring-ceph-for-openstack

Ceph cluster がすでに作成されている前提で、これ以降の手順を実施します。
Ceph cluster が起動していて、`HEALTH_OK` な状態かを確認します。

```
dev-storage01(mon) # ceph -s
```

`ceph osd pool create volumes` コマンドで、OpenStack 用のボリュームを作成します。
下記コマンドを実行すると、それぞれ`volumes`, `backups`, `images`, `vms` という名前で、デフォルトで rbd プールを作成します。

```
dev-storage01(mon) # ceph osd pool create volumes 128
dev-storage01(mon) # ceph osd pool create backups 128
dev-storage01(mon) # ceph osd pool create images 128
dev-storage01(mon) # ceph osd pool create vms 128
```

# Ceph クライアントをインストールする
Ceph クライアントを`Nova`, `Cinder`, `Cinder Backup` ノードにインストールします。

```
dev-storage01 # # dev-controller01,dev-computeXX(nova,nova-compute)
dev-storage01 # for node in dev-compute01 dev-compute02 dev-controller01; do
                    ssh ${node} -- apt-get update
                    ssh ${node} -- apt-get install -y python3-rbd ceph-common
                done
```

Glance ノードには`python-rbd` をインストールします。
今回は、controller ノードにGlance もインストールされているので、スキップします。

```
# Install python-rbd if you had a Glance node.
dev-storage01 # # dev-controller01(glance)
dev-storage01 # ssh dev-controller01 -- apt-get update
dev-storage01 # ssh dev-controller01 -- apt-get install python3-rbd
```

# Ceph 設定ファイルのコピー
Ceph 設定ファイルを、OpenStack ノードである`Nova`, `Cinder`, `Cinder Backup`, `Glance` ノードにコピーします
今回は、これらのサービスはcontroller ノードに集約されているので、コピー処理は割愛します。

```
### # mon node
### while read OPENSTACK_NODES in dev-novaXX dev-cinderXX dev-cinderbackuppXX dev-glanceXX; do
###     scp /etc/ceph/ceph.conf ${OPENSTACK_NODES}:/etc/ceph
### done
```

# Ceph クライアント認証を設定する
Ceph モニターノードから、Cinder, Cinder Backup, Glance のユーザを作成します。
今回のケースでは、Ceph モニターノードは、dev-storage01 になります。

```
dev-storage01(mon) # ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images'
dev-storage01(mon) # ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups'
dev-storage01(mon) # ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
```

`client.cinder`, `client.cinder-backup`, `client.glance` のためのkeyring を、適切なノードに追加します。
今回は、`dev-storage01` ノードに、これらの機能を集約しているので、そのノードの所定のファイルに、鍵情報を保存していきます。

```
dev-storage01(mon) # for i in $(seq 1 8); do
                         echo "Creating client.cinder dev-storage0${i}"
                         ceph auth get-or-create client.cinder | ssh dev-storage0${i} -- sudo tee /etc/ceph/ceph.client.cinder.keyring
                         ssh dev-storage0${i} -- chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
                     done

dev-storage01(mon) # # Same key as upper one
dev-storage01(mon) # for i in $(seq 1 2); do
                         echo "Creating client.cinder dev-compute0${i}"
                         ceph auth get-or-create client.cinder | ssh dev-compute0${i} -- sudo tee /etc/ceph/ceph.client.cinder.keyring
                         # A user "cinder" and a group "cinder" are not existed on each compute nodes. Set a owner "ceph:ceph" and permission 644 temporary.
                         ssh dev-compute0${i} -- bash -c "chown ceph:ceph /etc/ceph/ceph.client.cinder.keyring; chmod 644 /etc/ceph/ceph.client.cinder.keyring"
                     done

dev-storage01(mon) # for i in $(seq 1 8); do
                         echo "Creating client.cinder-backup dev-storage0${i}"
                         ceph auth get-or-create client.cinder-backup | ssh dev-storage0${i} -- sudo tee /etc/ceph/ceph.client.cinder-backup.keyring
                         ssh dev-storage01 -- chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring
                     done

dev-storage01(mon) # # nova-compute プロセスで使うクライアント鍵を、Nova ノードへコピーします。今回はNova はcontroller の中にあるので、そこへコピーします
dev-storage01(mon) # ceph auth get-or-create client.glance | ssh dev-controller01 -- sudo tee /etc/ceph/ceph.client.glance.keyring
dev-storage01(mon) # ssh dev-controller01 -- chown glance:glance /etc/ceph/ceph.client.glance.keyring

dev-storage01(mon) # # Controller ノードへは不要。Nova compute ノードのlibvirtd に登録するために必要
dev-storage01(mon) # # # libvirt に取り入れる`client.cinder` ユーザの鍵を、一時的に保管します。
dev-storage01(mon) # # # Cinder からデバイスを取り扱いできるようにするためです
dev-storage01(mon) # # # 鍵の内容は"ceph.ckient.cinder.keyring" と同じになります。
dev-storage01(mon) # # ceph auth get-or-create client.cinder | ssh dev-controller01 -- sudo tee client.cinder.key
```

OpenStack Nova ノードは、`nova-compute` プロセスのために、keyring ファイルを必要とします。
今回は、`dev-controller01` ノードに、これらの機能を集約しているので、そのノードの所定のファイルに、鍵情報を保存していきます。

```
dev-storage01(mon) # ceph auth get-or-create client.cinder | ssh dev-controller01 -- sudo tee /etc/ceph/ceph.client.cinder.keyring
```

OpenStack Nova ノードはまた、`libvirt` 内の`cinder.cinder` ユーザの秘密鍵を必要とします。
また、Cinder から、デバイスをアタッチしている間、クラスタにアクセスするために必要となります。

```
dev-storage01(mon) # for i in $(seq 1 2); do
                         ceph auth get-key client.cinder | ssh dev-compute0${i} -- sudo tee client.cinder.key
                     done
```

`exclusive-lock` 機能を使っている、Ceph ブロックデバイスイメージを含むストレージクラスタが含まれている場合、Ceph ブロックデバイスユーザは、クライアントをブラックリスト化する権限を持っている必要があります。
下記の書式のコマンドで、"osd blacklist" コマンドを許可するようにします。

```
(Example) # ceph auth caps client.ID mon 'allow r, allow command "osd blacklist"' osd 'EXISTING_OSD_USER_CAPS'
```

`client.ID` には、全Ceph ブロックデバイスユーザ分指定します。
`EXISTING_OSD_USER_CAPS` には、そのユーザが持っているcaps を指定します。

```
dev-storage01(mon) # ceph auth get client.cinder
[client.cinder]
        key = ........................................
        caps mon = "allow r"
        caps osd = "allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images"
exported keyring for client.cinder
dev-storage01(mon) # ceph auth caps client.cinder mon 'allow r, allow command "osd blacklist"' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images'

root@dev-storage01:~# ceph auth get client.cinder-backup
[client.cinder-backup]
        key = ........................................
        caps mon = "allow r"
        caps osd = "allow class-read object_prefix rbd_children, allow rwx pool=backups"
exported keyring for client.cinder-backup
dev-storage01(mon) # ceph auth caps client.cinder-backup mon 'allow r, allow command "osd blacklist"' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups'

root@dev-storage01:~# ceph auth get client.glance
[client.glance]
        key = ........................................
        caps mon = "allow r"
        caps osd = "allow class-read object_prefix rbd_children, allow rwx pool=images"
exported keyring for client.glance
dev-storage01(mon) # ceph auth caps client.glance mon 'allow r, allow command "osd blacklist"' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
```

Nova ノードにて、下記のコマンド実行し、UUID を生成します。

```
dev-controller01(nova) # uuidgen
3753f63d-338b-4f3d-b54e-a9117e7d9990
```

Nova compute ノードで、`libvirt` に、シークレットキーを登録します。
先程のコマンドで生成したUUID を全Nova コンピュータ上にコピーし、下記のコマンドを実行します。
厳密には、すべてのノードにUUID は必要ありませんが、プラットフォームの一貫性の側面から、同じUUID を指定することを推奨します。

```
dev-storage01(mon) # for i in $(seq 1 2); do
                         ssh dev-compute0${i} -- tee secret.xml << 'EOF'
<secret ephemeral='no' private='no'>
  <uuid>3753f63d-338b-4f3d-b54e-a9117e7d9990</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>
EOF
                     done
```

secret.xml ファイルを作成したら、登録します。

```
dev-storage01(mon) # # 下記コマンドで"error: Passing secret value as command-line argument is insecure!" というメッセージは出るが、設定はできています
dev-storage01(mon) # for i in $(seq 1 2); do
                         ssh -t dev-compute0${i} << 'EOF'
                             virsh secret-define --file secret.xml
                             virsh secret-set-value --secret 3753f63d-338b-4f3d-b54e-a9117e7d9990 --base64 $(cat client.cinder.key)
                             rm client.cinder.key secret.xml
EOF
                     done
```

確認を行うには、下記のコマンドを実行します。
```
dev-compute01 $ virsh secret-list
```

// Snapshot created_libvirtd_secret

# Ceph Block デバイスを使うための設定
; Chapter 3. Configuring OpenStack to use Ceph block devices
: https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/html/block_device_to_openstack_guide/configuring-openstack-to-use-ceph-block-devices

Ceph ブロックデバイスを、Cinder、Cinder Backup、Glance、Nova で使うための設定を行います。

## Ceph ブロックデバイスを使うためにCinder の設定
Ceph ブロックデバイスを使うために、Cinder のback-end ストレージとしてCeph を指定します。

```
# TODO: cinder.conf の権限設定のタイミングを、より適切なところにする
dev-controller01(cinder) # chown root:cinder /etc/cinder/cinder.conf
```

* /etc/cinder/cinder.conf @ dev-controller01(Cinder)
```
[DEFAULT]
...
enabled_backends = ceph

# You have to set "glance_api_version = 2" if you enable multiple_cinder_back_ends
glance_api_version = 2
...
# Create a cection "ceph"
[ceph]
volume_driver = cinder.volume.drivers.rbd.RBDDriver

# Specify a name of cluster and location of a config file of it. If you want to specify a name of cluster other than "ceph", you have to specify a name of cluster and change the location of it.
##rbd_cluster_name = jp-east
##rbd_ceph_conf = /etc/ceph/jp-east.conf

# Set a name of pool as "rbd". If you want to specify it to store data, you should specify like "rbd_pool".
rbd_pool = volumes

# Specify user-name and password
rbd_user = cinder
rbd_secret_uuid = 3753f63d-338b-4f3d-b54e-a9117e7d9990

rbd_flatten_volume_from_snapshot = false
rbd_max_clone_depth = 5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
```

デフォルトの`[lvm]` セクションの削除も実施してください。

## Cinder backup を設定する
Ceph block デバイスを使うように、cinder の設定ファイルの`[ceph]` セクションにcinder backup を設定します。

* /etc/cinder/cinder.conf @ dev-controller01(Cinder)
```
[ceph]
...
# Specify a driver ceph for backup_driver
backup_driver = cinder.backup.drivers.ceph
# Specify a location of file of backup_ceph_conf. You can specify it another file of ceph.
# You can specify another name of cluster by specifying another configuration for example.
backup_ceph_conf = /etc/ceph/ceph.conf
# A pool for backup_ceph
backup_ceph_pool = backups
backup_ceph_user = cinder-backup
# Specify configurations below additionally.
backup_ceph_chunk_size = 134217728
backup_ceph_stripe_unit = 0
backup_ceph_stripe_count = 0
restore_discard_excess_bytes = true
```

作成したcinder.conf ファイルを、各Nova compute, Storage ノードにコピーします。

```
dev-storage01 # scp dev-controller01:/etc/cinder/cinder.conf .
dev-storage01 # sed -i '/^my_ip = .*/d' cinder.conf
dev-storage01 # for i in $(seq 1 8); do
                    scp cinder.conf dev-storage0${i}:/etc/cinder/cinder.conf
                    ssh dev-storage0${i} -- bash -c \"chown root:cinder /etc/cinder/cinder.conf\; chmod 644 /etc/cinder/cinder.conf\"
                done
                for i in $(seq 1 2); do
                    ssh dev-compute0${i} -- mkdir -p /etc/cinder/
                    scp cinder.conf dev-compute0${i}:/etc/cinder/cinder.conf
                    #ssh dev-compute0${i} -- bash -c \"chown root:cinder /etc/cinder/cinder.conf\; chmod 644 /etc/cinder/cinder.conf\"
                    ssh dev-compute0${i} -- bash -c \"chmod 644 /etc/cinder/cinder.conf\"
                done
```

// Snapshot created_libvirtd_secret

## Horizon の設定

Cinder backup が有効化されているか確認します。

```
dev-controller01(cinder) # grep enable_backup /etc/openstack-dashboard/local_settings.py
```

False が設定されている場合、もしくは何も表示されない場合、それを`True` へ変更します。

* /etc/openstack-dashboard/local_settings.py @ dev-controller01(cinder)
```
OPENSTACK_CINDER_FEATURES = {
    'enable_backup': True,
}
```

// Snapshot enable_cinder_features_in_horizon

## Glance でCeph ブロックデバイスを使うように指定する
デフォルトでCeph ブロックデバイスを使うよう、`/etc/glance/glance-api.conf` ファイルを編集します。
異なるプール、ユーザ、Ceph 設定ファイルを適切な値に設定します。

* /etc/glance/glance-api.conf @ dev-controller01(glance)
```
[glance_store]
...
stores = rbd
default_store = rbd
rbd_store_chunk_size = 8
rbd_store_pool = images
rbd_store_user = glance
rbd_store_ceph_conf = /etc/ceph/ceph.conf

# To enable copy-on-write(CoW) cloning set, set "show_image_direct_url = True".
# Not to be public an endpoint for API if you enable CoW because the configuration of backend will be exposed.
show_image_direct_url = True

# Disable "cachemanagement" as you need.
# You can specify not "keystone+cachemanagement" but "keystone" instead.
flavor = keystone

# Set values recommended by Red Hat.
# You may be able to improbe performance and enable discard-operation by specifying "hw_scsi_model=virtio-scsi".
# // discard-operation is a feature not to use bad blocks on device.
# Each block devices will connect the controller by using drive of SCSI/SAS.
# It will also make qemu-guest-agent enabled and be able to send "fs-freeze/thaw" via QEMU guest agent.
hw_scsi_model=virtio-scsi
hw_disk_bus=scsi
hw_qemu_guest_agent=yes
os_require_quiesce=yes
```

```
TODO: 権限を設定するタイミングはここで良いのか。考える
dev-controller01(glance) # chown root:glance /etc/glance/glance-api.conf
```

// Snapshot configured_glance_api_for_ceph

## Nova を設定する
すべてのVM がephemeral back-end ストレージを利用できるよう、各Nova ノードに対して、設定を行います。

* /etc/ceph/ceph.conf @ dev-compute01,02(nova-compute)
```
[client]
rbd cache = true
rbd cache writethrough until flush = true
rbd concurrent management ops = 20
admin socket = /var/run/ceph/guests/$cluster-$type.$id.$pid.$cctid.asok
log file = /var/log/ceph/qemu-guest-$pid.log
```

管理ソケットとログファイルのためのディレクトリを作成します。

```
# TODO: ディレクトリ自体は、ゲストOS 作成時に自動的に作られていそう。AppArmor の設定だけで大丈夫か？
dev-compute01,02(nova-compute) # mkdir -p /var/run/ceph/guests/ /var/log/ceph/
dev-compute01,02(nova-compute) # chown libvirt-qemu:libvirt /var/run/ceph/guests /var/log/ceph/
```

`ceph.conf` ファイルを、controller(Glance) ノードにコピーします。

```
dev-storage01 # #scp dev-controller01:/etc/ceph/ceph.conf .
dev-storage01 # scp dev-compute01:/etc/ceph/ceph.conf .
dev-storage01 # scp ceph.conf dev-controller01:/etc/ceph/ceph.conf

dev-storage01 # #ssh dev-controller01 -- bash -c "chown ceph:ceph /etc/ceph/ceph.conf; chmod 644 /etc/ceph/ceph.conf"
dev-storage01 # ssh dev-controller01 -- bash -c \"chown ceph:ceph /etc/ceph/ceph.conf\; chmod 644 /etc/ceph/ceph.conf\"
```

// Snapshot configured_ceph_conf_for_nova_compute_nodes

## AppArmor の設定
AppArmor で上記ディレクトリを許可するように設定をします。

* /etc/apparmor.d/abstractions/libvirt-qemu @ dev-compute01,02
```
  /var/log/ceph/** rw,
  /var/run/ceph/guests/** rw,
```

* /etc/apparmor.d/usr.sbin.libvirtd @ dev-compute01,02
```
# 変更なし。既に"/** rwmkl," が定義されているため、不要
```

AppArmor の設定を適用します。

```
dev-compute01,02(Nova compute) # systemctl reload apparmor
```

各Nova compute ノードの`/etc/nova/nova.conf` ファイルの`[libvirt]` セクションを編集します。
`rbd_secret_uuid` には、qemu に登録したUUID と同じものを指定します。

* /etc/nova/nova.conf @ dev-compute01,02(nova-compute)
```
[libvirt]
images_type = rbd
images_rbd_pool = vms
images_rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_user = cinder
rbd_secret_uuid = 3753f63d-338b-4f3d-b54e-a9117e7d9990
disk_cachemodes="network=writeback"
inject_password = false
inject_key = false
inject_partition = -2
live_migration_flag="VIR_MIGRATE_UNDEFINE_SOURCE,VIR_MIGRATE_PEER2PEER,VIR_MIGRATE_LIVE,VIR_MIGRATE_PERSIST_DEST,VIR_MIGRATE_TUNNELLED"
hw_disk_discard = unmap
```

## keyring のコピー
TODO: keyring をコピーする適切なタイミングを考慮する。また、各ノード毎に、必要とするkeyring が異なるので、選別する。権限も、644 ではなく、640 でいけないか検証する。

```
dev-storage01(cinder) # for i in $(seq 1 2); do
                            scp /etc/ceph/*.keyring dev-compute0${i}:/etc/ceph/
                            ssh dev-compute0${i} -- bash -c \"chown ceph:ceph /etc/ceph/*.keyring \; chmod 644 /etc/ceph/*.keyring\"
                        done

dev-storage01(cinder) # scp /etc/ceph/*.keyring dev-controller01:/etc/ceph/
dev-storage01(cinder) # ssh dev-controller01 -- bash -c \"chown ceph:ceph /etc/ceph/*.keyring \; chmod 644 /etc/ceph/*.keyring\"
```

## OpenStack サービスを再起動する
```
dev-controller01(cinder controller) # systemctl restart cinder-scheduler
dev-controller01(cinder controller) # systemctl restart glance-api
dev-compute01,02(compute node) # systemctl restart nova-compute
```

// Snapshot prepared_ceph

# テストインスタンスを作成する
以下の手順は、テストインスタンスを作成する手順に加えて、ネットワーク、セキュリティグループ、SSH 公開鍵等も作成するので、テスト完了後は、適宜削除するようにしてください。

## ネットワークの作成
```
dev-controller01 # openstack network create --provider-network-type flat --provider-physical-network provider --external public
dev-controller01 # openstack network create --mtu 1400 --provider-network-type geneve --provider-segment 1001 private    # Is it too small in the config of Ansible?

dev-controller01 # openstack subnet create --network public --allocation-pool start=172.31.230.2,end=172.31.230.254 --no-dhcp --subnet-range 172.31.0.0/16 public_subnet
dev-controller01 # openstack subnet create --network private --allocation-pool start=192.168.255.2,end=192.168.255.254 --subnet-range 192.168.255.0/24 --dns-nameserver 172.31.0.1 --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 private_subnet

dev-controller01 # openstack router create private_router
dev-controller01 # openstack router set --external-gateway public private_router
dev-controller01 # openstack router add subnet private_router private_subnet
dev-controller01 # openstack router list

dev-controller01 # ovn-nbctl show
dev-controller01 # ovn-sbctl list datapath_binding
```

## イメージの作成
```
dev-controller01 # wget "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
dev-controller01 # openstack image create --disk-format qcow2 \
                       --container-format bare --public \
                       --file ./jammy-server-cloudimg-amd64.img "ubuntu"
```

## SSH 公開鍵の作成

```
dev-controller01 # ssh-keygen -t rsa -b 4096 -f ~/.ssh/example_openstack_id_rsa
dev-controller01 # openstack keypair create --public-key ~/.ssh/example_openstack_id_rsa.pub admin
dev-controller01 # openstack keypair list
```

## フレーバーの作成

```
dev-controller01 # openstack flavor create --id 1 --ram 512 --disk 8 --vcpus 1 m1.tiny
dev-controller01 # openstack flavor create --id 2 --ram 2048 --disk 8 --vcpus 2 m1.medium
dev-controller01 # openstack flavor list
```

## セキュリティグループの作成

```
dev-controller01 # openstack security group create permit_all --description "Allow all ports"
dev-controller01 # openstack security group rule create --protocol TCP --dst-port 1:65535 --remote-ip 0.0.0.0/0 permit_all
dev-controller01 # openstack security group rule create --protocol ICMP --remote-ip 0.0.0.0/0 permit_all

dev-controller01 # # 22, 80, 443 といった、基本的なポートのみのアクセス許可をするセキュリティグループを作成します
dev-controller01 # openstack security group create limited_access --description "Allow base ports"
dev-controller01 # openstack security group rule create --protocol ICMP --remote-ip 0.0.0.0/0 limited_access
dev-controller01 # openstack security group rule create --protocol TCP --dst-port 22 --remote-ip 0.0.0.0/0 limited_access
dev-controller01 # openstack security group rule create --protocol TCP --dst-port 80 --remote-ip 0.0.0.0/0 limited_access
dev-controller01 # openstack security group rule create --protocol TCP --dst-port 443 --remote-ip 0.0.0.0/0 limited_access

dev-controller01 # openstack security group list
```

## テストインスタンスの作成

```
cat << 'EOF' > cloud-init.yml
#cloud-config
hostname: ubuntu-server
fqdn: ubuntu-server.example.com
manage_etc_hosts: true
users:
  - name: ubuntu2
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/ubuntu2
    shell: /bin/bash
    # TODO: 'p@ssw0rd'
    passwd: $6$xyz$rfUoxhnScmjOykLAVIhgfxmKgIWmTirRSrIZ9j5EJ1Vf765rQS.dCbXjXBx4PuhbcNNrXx2XpwUywQ96C7EJB/
    lock_passwd: false
EOF

// Snapshot openstack_has_installed_before_instances_are_created

dev-controller01 # openstack server create --flavor m1.medium --image "ubuntu" \
                       --key-name admin --security-group permit_all --network private ubuntu-server --user-data cloud-init.yml

root@dev-controller01:~# openstack floating ip create --project admin --subnet public_subnet public
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| created_at          | 2023-08-04T17:10:46Z                 |
| description         |                                      |
| dns_domain          |                                      |
| dns_name            |                                      |
| fixed_ip_address    | None                                 |
| floating_ip_address | 172.31.230.163                       |
| floating_network_id | fcd7ebd0-b209-41d7-aaed-8a7d4325c568 |
| id                  | 5a4ef01d-c6d0-469f-ab34-34c62570d2ee |
| name                | 172.31.230.163                       |
| port_details        | None                                 |
| port_id             | None                                 |
| project_id          | ce69c6805db74221a1d181791d9c1e66     |
| qos_policy_id       | None                                 |
| revision_number     | 0                                    |
| router_id           | None                                 |
| status              | DOWN                                 |
| subnet_id           | 7c35b87e-75d0-4b9e-b4ad-498c5eebe32c |
| tags                | []                                   |
| updated_at          | 2023-08-04T17:10:46Z                 |
+---------------------+--------------------------------------+

root@dev-controller01:~# openstack floating ip list
+--------------------------------------+---------------------+------------------+--------------------------------------+--------------------------------------+----------------------------------+
| ID                                   | Floating IP Address | Fixed IP Address | Port                                 | Floating Network                     | Project                          |
+--------------------------------------+---------------------+------------------+--------------------------------------+--------------------------------------+----------------------------------+
| 5a4ef01d-c6d0-469f-ab34-34c62570d2ee | 172.31.230.163      | 192.168.255.154  | b3a451e4-3a72-4c3b-8992-6090bee9fb08 | fcd7ebd0-b209-41d7-aaed-8a7d4325c568 | ce69c6805db74221a1d181791d9c1e66 |
+--------------------------------------+---------------------+------------------+--------------------------------------+--------------------------------------+----------------------------------+

dev-controller01 # openstack server add floating ip ubuntu-server 172.31.230.163
> (no output)

dev-controller01 # openstack server list --long
+--------------------------------------+---------------+--------+------------+-------------+-----------------------------------------+------------+--------------------------------------+-------------+-----------+-------------------+---------------+------------+
| ID                                   | Name          | Status | Task State | Power State | Networks                                | Image Name | Image ID                             | Flavor Name | Flavor ID | Availability Zone | Host          | Properties |
+--------------------------------------+---------------+--------+------------+-------------+-----------------------------------------+------------+--------------------------------------+-------------+-----------+-------------------+---------------+------------+
| 599cb200-351b-4e8c-a79d-45eb452225fd | ubuntu-server | ACTIVE | None       | Running     | private=172.31.230.163, 192.168.255.154 | ubuntu     | f33e3f11-9e2d-436e-90fc-e2d3741b67b8 | m1.medium   | 2         | nova              | dev-compute02 |            |
+--------------------------------------+---------------+--------+------------+-------------+-----------------------------------------+------------+--------------------------------------+-------------+-----------+-------------------+---------------+------------+

## Volume を作成する
```
dev-controller01 # openstack availability zone list
+-----------+-------------+
| Zone Name | Zone Status |
+-----------+-------------+
| internal  | available   |
| nova      | available   |
| nova      | available   |
+-----------+-------------+

dev-storage01 # ceph osd lspools
1 volumes
2 backup
3 images
4 vms
5 .mgr

dev-storage01 # ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.03506  root default
-3         0.01169      host dev-cinder01
 1    hdd  0.01169          osd.1              up   1.00000  1.00000
-7         0.01169      host dev-cinder02
 0    hdd  0.01169          osd.0              up   1.00000  1.00000
-5         0.01169      host dev-cinder03
 2    hdd  0.01169          osd.2              up   1.00000  1.00000

dev-storage01 # ceph df
--- RAW STORAGE ---
CLASS    SIZE   AVAIL     USED  RAW USED  %RAW USED
hdd    36 GiB  26 GiB  9.5 GiB   9.5 GiB      26.41
TOTAL  36 GiB  26 GiB  9.5 GiB   9.5 GiB      26.41

--- POOLS ---
POOL     ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
volumes   1   32  977 MiB      253  2.9 GiB  10.41    8.2 GiB
backup    2   32      0 B        0      0 B      0    8.2 GiB
images    3   32  656 MiB       89  1.9 GiB   7.24    8.2 GiB
vms       4   32  1.5 GiB      429  4.6 GiB  15.60    8.2 GiB
.mgr      5    1  449 KiB        2  1.3 MiB      0    8.2 GiB

dev-storage01 # ceph-volume lvm list
> output info of volumes
```

