# Raid1 and LVM

```
# wipefs --all /dev/vd[ab]

# timeout 30 dd if=/dev/zero of=/dev/vda
# timeout 30 dd if=/dev/zero of=/dev/vdb
```

```
# sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" /dev/vda
# sgdisk -n 2:0:+256M -t 2:fd00 -c 2:"Linux RAID" /dev/vda
# sgdisk -n 3:0: -t 3:fd00 -c 3:"Linux RAID" /dev/vda

# sgdisk -R /dev/vdb -G /dev/vda
```

# Raid1 を作成する
```
# mdadm -C /dev/md1 -l0 -n2 -f /dev/vd[ab]2
# mdadm -C /dev/md2 -l0 -n2 -f /dev/vd[ab]3
# cat /proc/mdstat

# mdadm --detail /dev/md1
# mdadm --detail /dev/md2
```

# LVM を作成する
`/dev/md1`, `/dev/md2` 環境上にLVM を作成します。

```
# pvcreate /dev/md0 /dev/md1 /dev/md2
# pvdisplay
```

```
# vgcreate vg-boot /dev/md1
# vgcreate vg-root /dev/md2
# vgdisplay
```

```
# lvcreate -l 100%FREE -n lv-boot vg-boot
# lvcreate -l 100%FREE -n lv-root vg-root
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

