# Partition table succeeded in installing Ubuntu
Partition table that is succeeded in installing Ubuntu.
The partition table was created from an installer of Ubuntu.

```
root@ubuntu:~# gdisk -l /dev/vda
GPT fdisk (gdisk) version 1.0.5

Partition table scan:
  MBR: protective
  BSD: not present
  APM: not present
  GPT: present

Found valid GPT with protective MBR; using GPT.
Disk /dev/vda: 50331648 sectors, 24.0 GiB
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): C145F9F6-03E7-4046-8273-A65E83262026
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 50331614
Partitions will be aligned on 2048-sector boundaries
Total free space is 4029 sectors (2.0 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   1            2048         1050623   512.0 MiB   EF00
   2         1050624         2099199   512.0 MiB   8300
   3         2099200        50329599   23.0 GiB    8300
##############################################################################
root@ubuntu:~# cat /proc/mdstat
Personalities : [raid1] [linear] [multipath] [raid0] [raid6] [raid5] [raid4] [raid10]
md0 : active raid1 vda2[0] vdb2[1]
      523264 blocks super 1.2 [2/2] [UU]

md1 : active raid1 vdb3[1] vda3[0]
      24097792 blocks super 1.2 [2/2] [UU]

unused devices: <none>

root@ubuntu:~# pvdisplay
  --- Physical volume ---
  PV Name               /dev/md1
  VG Name               vg1
  PV Size               22.98 GiB / not usable 0
  Allocatable           yes (but full)
  PE Size               4.00 MiB
  Total PE              5883
  Free PE               0
  Allocated PE          5883
  PV UUID               3VlwK9-ExH7-wduK-gicc-RAA8-1eCB-r4YQ3h

  --- Physical volume ---
  PV Name               /dev/md0
  VG Name               vg0
  PV Size               511.00 MiB / not usable 3.00 MiB
  Allocatable           yes (but full)
  PE Size               4.00 MiB
  Total PE              127
  Free PE               0
  Allocated PE          127
  PV UUID               3vdovQ-1FI3-tnom-iz4v-Fajb-AOnp-s20nxS

root@ubuntu:~# vgdisplay
  --- Volume group ---
  VG Name               vg1
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  2
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               1
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               22.98 GiB
  PE Size               4.00 MiB
  Total PE              5883
  Alloc PE / Size       5883 / 22.98 GiB
  Free  PE / Size       0 / 0
  VG UUID               YM3fME-U1DQ-onD9-Qcnk-P4vU-75da-1AjRD5

  --- Volume group ---
  VG Name               vg0
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  2
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               1
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               508.00 MiB
  PE Size               4.00 MiB
  Total PE              127
  Alloc PE / Size       127 / 508.00 MiB
  Free  PE / Size       0 / 0
  VG UUID               xY6u7q-JgKH-Grh3-fQkL-gis8-Kh4k-e3CwBM

root@ubuntu:~# lvdisplay
  --- Logical volume ---
  LV Path                /dev/vg1/lv-0
  LV Name                lv-0
  VG Name                vg1
  LV UUID                MrKVYt-Wkx4-nzzl-FNib-4PCp-PjSk-CnJaVw
  LV Write Access        read/write
  LV Creation host, time ubuntu-server, 2022-01-08 18:11:21 +0000
  LV Status              available
  # open                 1
  LV Size                22.98 GiB
  Current LE             5883
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           253:1

  --- Logical volume ---
  LV Path                /dev/vg0/lv-0
  LV Name                lv-0
  VG Name                vg0
  LV UUID                6VIMuq-Rrxe-fnIo-mgSF-wrnw-SfE1-FudjhI
  LV Write Access        read/write
  LV Creation host, time ubuntu-server, 2022-01-08 18:11:19 +0000
  LV Status              available
  # open                 1
  LV Size                508.00 MiB
  Current LE             127
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           253:0
```

