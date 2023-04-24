# Ceph for OpenStack

; Chapter 2. Installing and configuring Ceph for OpenStack
: https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/html/block_device_to_openstack_guide/installing-and-configuring-ceph-for-openstack

Ceph cluster がすでに作成されている前提で、これ以降の手順を実施します。
Ceph cluster が起動していて、`HEALTH_OK` な状態かを確認します。

```
dev-storage01 # ceph -s
```

`ceph osd pool create volumes` コマンドで、OpenStack 用のボリュームを作成します。
下記コマンドを実行すると、それぞれ`volumes`, `backups`, `images`, `vms` という名前で、デフォルトで rbd プールを作成します。

```
dev-storage01 # ceph osd pool create volumes 128
dev-storage01 # ceph osd pool create backups 128
dev-storage01 # ceph osd pool create images 128
dev-storage01 # ceph osd pool create vms 128
```

# Ceph クライアントをインストールする
Ceph クライアントを`Nova`, `Cinder`, `Cinder Backup` ノードにインストールします。

```
dev-{compute,controller}XX # apt-get update
dev-{compute,controller}XX # apt-get intall python-rbd ceph-common
```

Glance ノードには`python-rbd` をインストールします。
今回は、controller ノードにGlance もインストールされているので、スキップします。

```
# Install python-rbd if you had a Glance node.
dev-glanceXX # apt-get update
dev-glanceXX # apt-get intall python-rbd
```

# Ceph 設定ファイルのコピー
Ceph 設定ファイルを、OpenStack ノードである`Nova`, `Cinder`, `Cinder Backup`, `Glance` ノードにコピーします
今回は、これらのサービスはcontroller ノードに集約されているので、コピー処理は割愛します。

```
### while read OPENSTACK_NODES in dev-novaXX dev-cinderXX dev-cinderbackuppXX dev-glanceXX; do
###     scp /etc/ceph/ceph.conf ${OPENSTACK_NODES}:/etc/ceph
### done
```

# Ceph クライアント認証を設定する
Ceph モニターノードから、Cinder, Cinder Backup, Glance のユーザを作成します。
今回のケースでは、Ceph モニターノードは、dev-controller01 になります。

```
dev-controller01 # ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images'
dev-controller01 # ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups'
dev-controller01 # ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
```


