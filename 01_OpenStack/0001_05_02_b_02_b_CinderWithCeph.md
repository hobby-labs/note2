## ファイルシステムを使用する
; Use File System
: https://www.server-world.info/en/note?os=Ubuntu_22.04&p=ceph&f=4

; Introduction to Ceph
: https://parhamzardoshti.medium.com/introduction-to-ceph-7ed07be08a69

; CEPH FILE SYSTEM
: https://docs.ceph.com/en/quincy/cephfs/index.html

; CREATE A CEPH FILE SYSTEM
: https://docs.ceph.com/en/quincy/cephfs/createfs/

SSH の鍵の転送については、手順を割愛します。  
  
ノード上のMetaData Server を設定します。
まず、ディレクトリを作成します。
ディレクトリ名はクラスタ名とノード名を含む`directory name ⇒ (Cluster Name)-(Node Name)` となるようにしてください。
これらのコマンドは、ストレージサーバ全体で共有されますので、いずれか1 つのノードで実行してください。
複数プールを作成する場合も、ストレージサーバ全体で共有されているため、それぞれことなる名前で作成してください。

```
dev-storage01 # mkdir -p /var/lib/ceph/mds/ceph-${HOSTNAME}
dev-storage01 # ceph-authtool --create-keyring /var/lib/ceph/mds/ceph-${HOSTNAME}/keyring --gen-key -n mds.${HOSTNAME}
creating ...
dev-storage01 # chown -R ceph. /var/lib/ceph/mds/ceph-${HOSTNAME}
dev-storage01 # ceph auth add mds.${HOSTNAME} osd "allow rwx" mds "allow" mon "allow profile mds" -i /var/lib/ceph/mds/ceph-${HOSTNAME}/keyring
added key for mds.${HOSTNAME}
dev-storage01 # systemctl enable --now ceph-mds@${HOSTNAME}
```

MDS ノード上に2 つのRADOS プールを作成します。

; 参考
: https://community.cisco.com/t5/tkb-%E3%83%87%E3%83%BC%E3%82%BF%E3%82%BB%E3%83%B3%E3%82%BF%E3%83%BC-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88/cvim-ceph-placement-group-%E3%81%AB%E3%81%A4%E3%81%84%E3%81%A6/ta-p/4121577

```
dev-storage01 # # 下記のCeph プールを作成するコマンドの数字は、下記ドキュメントを参照してください
dev-storage01 # # http://docs.ceph.com/docs/master/rados/operations/placement-groups/
dev-storage01 # ceph osd pool create cephfs_data 32
> pool 'cephfs_data' created
dev-storage01 # ceph osd pool create cephfs_metadata 32
> pool 'cephfs_metadata' created
dev-storage01 # # Pool が作成されたら、`fs new` コマンドで、それを有効化します
dev-storage01 # ceph fs new cephfs cephfs_metadata cephfs_data
> new fs with metadata pool 3 and data pool 2
dev-storage01 # ceph fs ls
> name: cephfs, metadata pool: cephfs_metadata, data pools: [cephfs_data ]
dev-storage01 # ceph mds stat
cephfs:1 {0=dev-storage01=up:active}
dev-storage01 # ceph fs status cephfs
cephfs - 0 clients
======
RANK  STATE        MDS          ACTIVITY     DNS    INOS   DIRS   CAPS
 0    active  dev-storage01  Reqs:    0 /s    10     13     12      0
      POOL         TYPE     USED  AVAIL
cephfs_metadata  metadata  96.0k  7771M
  cephfs_data      data       0   7771M
MDS version: ceph version 17.2.5 (98318ae89f1a893a6ded3a640405cdbb33e08757) quincy (stable)
```

クライアントで、CephFS をマウントします。
```
dev-compute01 # # Create base64 encoded client key
dev-compute01 # ceph-authtool -p /etc/ceph/ceph.client.admin.keyring > admin.key
dev-compute01 # chmod 600 admin.key
dev-compute01 # mount -t ceph dev-storage01.openstack.example.com:6789:/ /mnt -o name=admin,secretfile=admin.key
dev-compute01 # df -hT
Filesystem          Type   Size  Used Avail Use% Mounted on
tmpfs               tmpfs  1.6G  1.3M  1.6G   1% /run
/dev/vda1           ext4    51G  7.4G   44G  15% /
tmpfs               tmpfs  7.9G     0  7.9G   0% /dev/shm
tmpfs               tmpfs  5.0M     0  5.0M   0% /run/lock
tmpfs               tmpfs  7.9G     0  7.9G   0% /run/qemu
/dev/vda15          vfat   105M  6.1M   99M   6% /boot/efi
tmpfs               tmpfs  1.6G  4.0K  1.6G   1% /run/user/1000
172.22.1.101:6789:/ ceph   7.6G     0  7.6G   0% /mnt
```

# 複数のファイルシステムをマウントする
; ceph status
: https://serverfault.com/questions/814741/how-do-i-mount-one-of-multiple-filesystems-in-a-ceph-cluster

; 2.8. 複数のアクティブな Metadata Server デーモンの設定
: https://access.redhat.com/documentation/ja-jp/red_hat_ceph_storage/5/html/file_system_guide/configuring-multiple-active-metadata-server-daemons_fs

1 クラスタで複数のファイルシステムを作成して、マウントする方法です。
それぞれのファイルシステムに、それぞれのmds が必要になります。

