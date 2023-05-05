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
                         ssh dev-storage01 -- chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
                     done

dev-storage01(mon) # for i in $(seq 1 8); do
                         echo "Creating client.cinder-backup dev-storage0${i}"
                         ceph auth get-or-create client.cinder-backup | ssh dev-storage0${i} -- sudo tee /etc/ceph/ceph.client.cinder-backup.keyring
                         ssh dev-storage01 -- chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring
                     done

dev-storage01(mon) # ceph auth get-or-create client.glance | ssh dev-controller01 -- sudo tee /etc/ceph/ceph.client.glance.keyring
dev-storage01(mon) # ssh dev-controller01 -- chown glance:glance /etc/ceph/ceph.client.glance.keyring
```

OpenStack Nova ノードは、`nova-compute` プロセスのために、keyring ファイルを必要とします。
今回は、`dev-controller01` ノードに、これらの機能を集約しているので、そのノードの所定のファイルに、鍵情報を保存していきます。

```
dev-storage01(mon) # ceph auth get-or-create client.cinder | ssh dev-controller01 -- sudo tee /etc/ceph/ceph.client.cinder.keyring
```

OpenStack Nova ノードはまた、`libvirt` 内の`cinder.cinder` ユーザの秘密鍵を必要とします。
また、Cinder から、デバイスをアタッチしている間、クラスタにアクセスするために必要となります。

```
dev-storage01(mon) # # TODO: Nova コントローラノードにはコピーしないが、それで大丈夫か
dev-storage01(mon) # for i in $(seq 1 2); do
                         ceph auth get-key client.cinder | ssh dev-compute0${i} -- sudo tee client.cinder.key
                     done
```

`exclusive-lock` 機能を使っている、Ceph ブロックデバイスイメージを含むストレージクラスタが含まれている場合、Ceph ブロックデバイスユーザは、クライアントをブラックリスト化する権限を持っている必要があります。
下記の書式のコマンドで、"osd blacklist" コマンドを許可するようにします。

```
ceph auth caps client.ID mon 'allow r, allow command "osd blacklist"' osd 'EXISTING_OSD_USER_CAPS'
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
dev-storage01(mon) # # "error: Passing secret value as command-line argument is insecure!" というメッセージは出るが、設定はできています
dev-storage01(mon) # for i in $(seq 1 2); do
                         ssh -t dev-compute0${i} << 'EOF'
                             virsh secret-define --file secret.xml
                             virsh secret-set-value --secret 3753f63d-338b-4f3d-b54e-a9117e7d9990 --base64 $(cat client.cinder.key)
                             rm client.cinder.key secret.xml
EOF
                     done
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

* /etc/cinder/cinder.conf @ dev-controller01(cinder)
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

デフォルトの`[lvm]` セクションの削除も検討してください。

## Cinder backup を設定する
Ceph block デバイスを使うように、cinder の設定ファイルの`[ceph]` セクションにcinder backup を設定します。

* /etc/cinder/cinder.conf @ dev-controller01(cinder)
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
dev-compute01,02(nova-compute) # mkdir -p /var/run/ceph/guests/ /var/log/ceph/
dev-compute01,02(nova-compute) # chown libvirt-qemu:libvirt /var/run/ceph/guests /var/log/ceph/
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

## OpenStack サービスを再起動する
```
dev-controller01(cinder) # systemctl restart cinder-scheduler
dev-controller01(cinder) # systemctl restart glance-api
dev-compute01,02(nova) # systemctl restart nova-compute
```

// Snapshot prepared_ceph

