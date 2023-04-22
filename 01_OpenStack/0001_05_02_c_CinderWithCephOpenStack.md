# Ceph for OpenStack

; Chapter 2. Installing and configuring Ceph for OpenStack
: https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/html/block_device_to_openstack_guide/installing-and-configuring-ceph-for-openstack

`ceph osd pool create volumes` コマンドで、OpenStack 用のボリュームを作成します。
下記コマンドを実行すると、デフォルトで rbd プールを作成します。

```
# ceph osd pool create volumes 128
# ceph osd pool create backups 128
# ceph osd pool create images 128
# ceph osd pool create vms 128
```

