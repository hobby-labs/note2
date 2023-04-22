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
dev-{compute,controller}XX # apt-get update
```

