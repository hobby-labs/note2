# Ceph for OpenStack

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
dev-{compute,controller}XX(nova-compute) # apt-get update
dev-{compute,controller}XX(nova-compute) # apt-get intall python-rbd ceph-common
```

Glance ノードには`python-rbd` をインストールします。
今回は、controller ノードにGlance もインストールされているので、スキップします。

```
# Install python-rbd if you had a Glance node.
dev-glanceXX(glance) # apt-get update
dev-glanceXX(glance) # apt-get intall python-rbd
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
今回のケースでは、Ceph モニターノードは、dev-controller01 になります。

```
dev-controller01(mon) # ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images'
dev-controller01(mon) # ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups'
dev-controller01(mon) # ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
```

`client.cinder`, `client.cinder-backup`, `client.glance` のためのkeyring を、適切なノードに追加します。
今回は、`dev-controller01` ノードに、これらの機能を集約しているので、そのノードの所定のファイルに、鍵情報を保存していきます。

```
dev-controller01(mon) # ceph auth get-or-create client.cinder > /etc/ceph/ceph.client.cinder.keyring
dev-controller01(mon) # chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring
dev-controller01(mon) # ceph auth get-or-create client.cinder-backup > /etc/ceph/ceph.client.cinder-backup.keyring
dev-controller01(mon) # chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring
dev-controller01(mon) # ceph auth get-or-create client.glance > /etc/ceph/ceph.client.glance.keyring
dev-controller01(mon) # chown glance:glance /etc/ceph/ceph.client.glance.keyring
```

OpenStack Nova ノードは、`nova-compute` プロセスのために、keyring ファイルを必要とします。
今回は、`dev-controller01` ノードに、これらの機能を集約しているので、そのノードの所定のファイルに、鍵情報を保存していきます。

```
dev-controller01(mon) # ceph auth get-or-create client.cinder > /etc/ceph/ceph.client.cinder.keyring
```

OpenStack Nova ノードはまた、`libvirt` 内の`cinder.cinder` ユーザの秘密鍵を必要とします。
また、Cinder から、デバイスをアタッチしている間、クラスタにアクセスするために必要となります。

```
dev-controller01(mon) # ceph auth get-key client.cinder > client.cinder.key
```

`exclusive-lock` 機能を使っている、Ceph ブロックデバイスイメージを含むストレージクラスタが含まれている場合、Ceph ブロックデバイスユーザは、クライアントをブラックリスト化する権限を持っている必要があります。

```
dev-controller01(mon) # ceph auth caps client.ID mon 'allow r, allow command "osd blacklist"' osd 'EXISTING_OSD_USER_CAPS'
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
dev-controller01(nova) # cat > secret.xml <<EOF
<secret ephemeral='no' private='no'>
  <uuid>3753f63d-338b-4f3d-b54e-a9117e7d9990</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>
EOF
```

secret.xml ファイルを作成したら、登録します。

```
dev-controller01(nova) # virsh secret-define --file secret.xml
dev-controller01(nova) # virsh secret-set-value --secret 3753f63d-338b-4f3d-b54e-a9117e7d9990 --base64 $(cat client.cinder.key) && rm client.cinder.key secret.xml
```

# Ceph Block デバイスを使うための設定
; Chapter 3. Configuring OpenStack to use Ceph block devices
: https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/html/block_device_to_openstack_guide/configuring-openstack-to-use-ceph-block-devices

Ceph ブロックデバイスを、Cinder、Cinder Backup、Glance、Nova で使うための設定を行います。

## Ceph ブロックデバイスを使うためにCinder の設定
Ceph ブロックデバイスを使うために、Cinder のback-end ストレージとしてCeph を指定します。

* /etc/cinder/cinder.conf @ dev-controller01(cinder)
```
[DEFAULT]
...
enabled_backends = ceph
# multiple cinder back ends を設定したら、glance_api_version を2 に設定する必要があります
glance_api_version = 2
...
# ceph セクションを新規作成する
[ceph]
volume_driver = cinder.volume.drivers.rbd.RBDDriver

# Cluster 名とCeph ファイルの場所を指定する。cluster 名を"ceph" 意外に設定する場合、ファイルの場所を適切なものに設定する必要があります
rbd_cluster_name = jp-east
rbd_ceph_conf = /etc/ceph/jp-east.conf

# Ceph ボリュームを、デフォルトで`rbd` pool に保存します。事前に作成された、pool に保存するようにするには、`rbd_pool` で指定する必要があります
rbd_pool = volumes

# ユーザ名とパスワードを指定します
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

* /etc/cinder/cinder.conf
```
[ceph]
...
# backup_driver として、Ceph ドライバに指定します
backup_driver = cinder.backup.drivers.ceph
# backup_ceph_conf 設定ファイルを指定します。このファイルは、Cinder のCeph 設定ファイルと違うものにすることがでます。
# 具体的には、クラスタ名を異なるものにすることができます
backup_ceph_conf = /etc/ceph/ceph.conf
# backup ceph に使うPool を指定します
backup_ceph_pool = backups
# ユーザを指定します
backup_ceph_user = cinder-backup
# その他、下記設定を追加します
backup_ceph_chunk_size = 134217728
backup_ceph_stripe_unit = 0
backup_ceph_stripe_count = 0
restore_discard_excess_bytes = true
```

Cinder backup が有効化されているか確認します。

```
dev-controller01(cinder) # grep enable_backup /etc/openstack-dashboard/local_settings
```

False が設定されている場合、それを`True` へ変更します。

* /etc/openstack-dashboard/local_settings @ dev-controller01(cinder)
```
OPENSTACK_CINDER_FEATURES = {
    'enable_backup': True,
}
```

## Glance でCeph ブロックデバイスを使うように指定する
デフォルトでCeph ブロックデバイスを使うよう、`/etc/glance/glance-api.conf` ファイルを編集します。
異なるプール、ユーザ、Ceph 設定ファイルを適切な値に設定します。

* /etc/glance/glance-api.conf @ dev-controller01(glance)
```
stores = rbd
default_store = rbd
rbd_store_chunk_size = 8
rbd_store_pool = images
rbd_store_user = glance
rbd_store_ceph_conf = /etc/ceph/ceph.conf

# copy-on-write(CoW) cloning set を有効化するために、`show_image_direct_url` を`True` に設定します。
# この設定は、Glance API 経由で、バックエンドのロケーションをさらけ出すことになるので、CoW を有効化する場合、エンドポイントは公開すべきではありません
show_image_direct_url = True

# 必要に応じて、cache management を無効化します。
# "keystone+cachemanagement" ではなく、"keystone" のみを指定します
flavor = keystone

# Red Hat として推奨されている値を設定します。
# hw_scsi_model=virtio-scsi を設定することで、パフォーマンスを向上でき、discard operation(不良ブロックを使わないようにする機能?) を有効化することができます。
# SCSI/SAS ドライブをつ開くことで、各Cinder ブロックデバイスはそのコントローラに接続するようになります。
# また、QEMU ゲストエージェントを有効にし、`fs-freeze/thaw` をQEMU ゲストエージェント経由で送信することができます。
hw_scsi_model=virtio-scsi
hw_disk_bus=scsi
hw_qemu_guest_agent=yes
os_require_quiesce=yes
```

