# Ceph をブロックデバイスとして使用する
## クライアントでのデバイス作成とマウント
ここから先は、Ceph クライアントノードで作業を実施していきます。
クライアント側でデバイスを作成し、マウントするために、まずプールを作成します。
ここでは<code>rbd(RADOS Block Device)</code> プールを作成します。

```
dev-storage01 # ceph osd pool create rbd 32
```

// プール数について    
https://docs.ceph.com/en/latest/rados/operations/placement-groups/#choosing-number-of-placement-groups  

Placement グループのオートスケールを有効化します。

* dev-compute0{1,2} 
```
// dev-compute0{1,2} でも実行可能
dev-storage01 # ceph osd pool set rbd pg_autoscale_mode on
```

オートスケールの初期化と、状態の確認をします。

```
// dev-compute0{1,2} でも実行可能
dev-storage01 # rbd pool init rbd
dev-storage01 # ceph osd pool autoscale-status
```

1GB のブロックデバイスを作成します。

```
// dev-compute0{1,2} でも実行可能
dev-storage01 # rbd create --size 1GB --pool rbd rbd01

// dev-compute0{1,2} でも実行可能
dev-storage01 # rbd ls -l
NAME   SIZE   PARENT  FMT  PROT  LOCK
rbd01  1 GiB            2
```

// Snapshot create_ceph_block_device

デバイスをマッピングします。
クライアントノードで下記コマンドを実行し、クライアントのドライブにマッピングします。
```
dev-compute01 # rbd map rbd01
// 1 デバイス1 クライアントでマッピングします。現状、この設定では1 デバイス複数クライアントでマッピング/マウントして使用しても、正常に利用できません

dev-compute01 # rbd showmapped
id  pool  namespace  image  snap  device
0   rbd              rbd01  -     /dev/rbd0
```

ブロックデバイスをフォーマットします。

```
dev-compute01 # mkfs.xfs /dev/rbd0
```

```
dev-compute01 # mount /dev/rbd0 /mnt
```

## ブロックデバイス、Pool の削除
デバイスのunmap をするには、<code>rbd unmap</code> コマンドを実行します。

```
dev-compute01 # umount /dev/rbd0
dev-compute01 # rbd unmap /dev/rbd/rbd/rbd01
```

Block デバイスを削除する。

```
dev-compute01 # rbd rm rbd01 -p rbd
```

```
dev-compute01 # ceph osd pool delete rbd rbd --yes-i-really-really-mean-it
```

// Snapshot removed_ceph_block_device
