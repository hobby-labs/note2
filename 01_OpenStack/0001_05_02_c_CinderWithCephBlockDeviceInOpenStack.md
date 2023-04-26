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

Nova ノードにて、下記のコマンド実行します。

```
dev-controller01(nova) # uuidgen > uuid-secret.txt
```

