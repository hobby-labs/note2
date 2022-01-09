# Raid1 and LVM

```
# wipefs --all /dev/vd[ab]

# timeout 30 dd if=/dev/zero of=/dev/vda
# timeout 30 dd if=/dev/zero of=/dev/vdb
```

```
# sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" /dev/vda
# sgdisk -n 2:0:+512M -t 2:8e00 -c 2:"Linux LVM" /dev/vda
# sgdisk -n 3:0: -t 3:8e00 -c 3:"Linux LVM" /dev/vda

# sgdisk -R /dev/vdb -G /dev/vda
```

# LVM を作成する

```
# pvcreate /dev/vda2 /dev/vdb2 /dev/vda3 /dev/vdb3
# pvdisplay
```

```
# vgcreate vg-boot /dev/vda2 /dev/vdb2
# vgcreate vg-root /dev/vda3 /dev/vdb3
# vgdisplay
```

```
# lvcreate -l 100%FREE -m1 -n lv-boot vg-boot
# lvcreate -l 100%FREE -m1 -n lv-root vg-root
# lvdisplay
-> "/dev/vg-root/lv-root", "/dev/vg-boot/lv-boot" がLVM のパスとなる
```

```
# mkfs.vfat -F32 /dev/vda1
# mkfs.vfat -F32 /dev/vdb1
```

## Ubuntu をインストールする
下記の構成になるようにディスクを指定して、Ubuntu のインストールを開始します。

```
/dev/vda1  /boot/efi    vfat
lv-boot    /boot        ext4
lv-root    /            xfs
```

## EFI 領域をコピーする
片方どちらかのディスクに障害があっても、必ず起動できるように、もう片方のディスクのEFI パーティションをコピーしておきます。

```
# dd if=/dev/vda1 of=/dev/vdb1
```

# エラーから復旧する
片系のディスクが落ちて、そのディスクを付け替えた後の復旧手順。

```
# pvdisplay

// ...

  WARNING: Couldn't find device with uuid JgVEs7-wr0q-cCvD-ybMb-eSZm-XHCe-a4yG4F.
  WARNING: VG vg-root is missing PV JgVEs7-wr0q-cCvD-ybMb-eSZm-XHCe-a4yG4F (last written to /dev/vda3).
  --- Physical volume ---
  PV Name               [unknown]
  VG Name               vg-root
  PV Size               <23.00 GiB / not usable 2.98 MiB
  Allocatable           yes (but full)
  PE Size               4.00 MiB
  Total PE              5887
  Free PE               0
  Allocated PE          5887
  PV UUID               JgVEs7-wr0q-cCvD-ybMb-eSZm-XHCe-a4yG4F

// ...
```

```
# sgdisk -R /dev/vdb -G /dev/vda
```

https://serverfault.com/a/534283/253941

