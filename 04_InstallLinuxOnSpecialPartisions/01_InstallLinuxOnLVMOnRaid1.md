# Raid1 and LVM

```
# wipefs --all /dev/vd[ab]

# timeout 30 dd if=/dev/zero of=/dev/vda
# timeout 30 dd if=/dev/zero of=/dev/vdb
```

```
# sgdisk -n 1:0:+512M -t 1:fd00 -c 1:"Linux RAID" /dev/vda
# sgdisk -n 2:0:+256M -t 2:fd00 -c 2:"Linux RAID" /dev/vda
# sgdisk -n 3:0: -t 3:fd00 -c 3:"Linux RAID" /dev/vda

# ###sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI System" /dev/sda
# ###sgdisk -n 2:0:+256M -t 2:fd00 -c 2:"Linux RAID" /dev/vda
# ###sgdisk -n 3:0: -t 3:fd00 -c 3:"Linux RAID" /dev/vda

# sgdisk -R /dev/vdb -G /dev/vda
```

# Raid1 を作成する
```
# mdadm -C /dev/md0 -l0 -n2 -f /dev/vd[ab]1
# mdadm -C /dev/md1 -l0 -n2 -f /dev/vd[ab]2
# mdadm -C /dev/md2 -l0 -n2 -f /dev/vd[ab]3
# cat /proc/mdstat

# mdadm --detail /dev/md0
# mdadm --detail /dev/md1
# mdadm --detail /dev/md2
```

# LVM を作成する
`/dev/md0`, `/dev/md1`, `/dev/md2` 環境上にLVM を作成する。

```
# pvcreate /dev/md0 /dev/md1 /dev/md2
# pvdisplay
```

```
# vgcreate vg-efi  /dev/md0
# vgcreate vg-boot /dev/md1
# vgcreate vg-root /dev/md2
# vgdisplay
```

```
# lvcreate -l 100%FREE -n lv-efi vg-efi
# lvcreate -l 100%FREE -n lv-boot vg-boot
# lvcreate -l 100%FREE -n lv-root vg-root
```

## Ubuntu をインストールする

```
lv-efi     /boot/efi    vfat
lv-boot    /boot        ext4
lv-root    /            xfs
```

## EFI 領域をコピーする

```
# dd if=/dev/sda1 of=/dev/sdb1
```


