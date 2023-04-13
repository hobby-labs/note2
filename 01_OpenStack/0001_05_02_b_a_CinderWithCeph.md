= Ceph をブロックデバイスとして使用する =
== クライアントでのデバイス作成とマウント ==
ここから先は、Ceph クライアントノードで作業を実施していきます。
クライアント側でデバイスを作成し、マウントするために、まずプールを作成します。
ここでは<code>rbd</code> プールを作成します。

<syntaxhighlight lang="console">
dev-storage01 # ceph osd pool create rbd 32
</syntaxhighlight>

// プール数について  
https://docs.ceph.com/en/latest/rados/operations/placement-groups/#choosing-number-of-placement-groups  

Placement グループのオートスケールを有効化します。

* dev-compute0{1,2} 
<syntaxhighlight lang="console">
// dev-compute0{1,2} でも実行可能
dev-storage01 # ceph osd pool set rbd pg_autoscale_mode on
</syntaxhighlight>

オートスケールの初期化と、状態の確認をします。

<syntaxhighlight lang="console">
// dev-compute0{1,2} でも実行可能
dev-storage01 # rbd pool init rbd
dev-storage01 # ceph osd pool autoscale-status
</syntaxhighlight>

1GB のブロックデバイスを作成します。

<syntaxhighlight lang="console">
// dev-compute0{1,2} でも実行可能
dev-storage01 # rbd create --size 1GB --pool rbd rbd01

// dev-compute0{1,2} でも実行可能
dev-storage01 # rbd ls -l
NAME   SIZE   PARENT  FMT  PROT  LOCK
rbd01  1 GiB            2
</syntaxhighlight>

// Snapshot create_ceph_block_device

デバイスをマッピングします。
クライアントノードで下記コマンドを実行し、クライアントのドライブにマッピングします。
<syntaxhighlight lang="console">
dev-compute01 # rbd map rbd01
// 1 デバイス1 クライアントでマッピングします。現状、この設定では1 デバイス複数クライアントでマッピング/マウントして使用しても、正常に利用できません

dev-compute01 # rbd showmapped
id  pool  namespace  image  snap  device
0   rbd              rbd01  -     /dev/rbd0
</syntaxhighlight>

ブロックデバイスをフォーマットします。

<syntaxhighlight lang="console">
dev-compute01 # mkfs.xfs /dev/rbd0
</syntaxhighlight>


<syntaxhighlight lang="console">
dev-compute01 # mount /dev/rbd0 /mnt
</syntaxhighlight>

== ブロックデバイス、Pool の削除 ==
デバイスのunmap をするには、<code>rbd unmap</code> コマンドを実行します。

<syntaxhighlight lang="console">
dev-compute01 # umount /dev/rbd0
dev-compute01 # rbd unmap /dev/rbd/rbd/rbd01
</syntaxhighlight>

Block デバイスを削除する。

<syntaxhighlight lang="console">
dev-compute01 # rbd rm rbd01 -p rbd
</syntaxhighlight>

<syntaxhighlight lang="console">
dev-compute01 # ceph osd pool delete rbd rbd --yes-i-really-really-mean-it
</syntaxhighlight>

// Snapshot removed_ceph_block_device
