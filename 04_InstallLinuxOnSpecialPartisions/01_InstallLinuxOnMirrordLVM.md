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

# sgdisk -R /dev/vdb /dev/vda
# sgdisk -G /dev/vdb
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

## セカンダリデバイスのEFI 領域をfstab にコメントとして残しておく
障害時に`/boot/efi` マウントポイントを復旧しやすくするために、スペア側のディスクの`/boot/efi` 領域をマウントする定義を書いておきましょう。
そうすることで、もし`/dev/vda` に障害が発生してしまった時に、`/dev/vdb` 側のコメントを解除することで、スムーズに切り替えられるようになります。

```
# uuid="$(blkid | grep -P '/dev/vdb1' | sed -e 's/.* UUID="\([^"]\+\)".*/\1/g')"
# prinof '#/dev/disk/by-uuid/%s /boot/efi vfat defaults 0 1\n' "$uuid" >> /etc/fstab
```

# エラーから復旧する
片系のディスクが落ちて、そのディスクを付け替えた後の復旧手順。
`/dev/vda` が故障して、それを新しいやつに取り替えた後を想定した手順です。
作業対象のドライブレターを間違えるとシステムが破壊されうるので、注意してください。

```
## pvdisplay

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
-> "[unknown]" なステータスの物理ボリュームが確認できる。

// ...
```

## fstab に記載されている/boot/efi をマウントするデバイスが、生存している方のものか確認する
fstab の/boot/efi 領域のマウントデバイスを変更する。
/boot/efi 領域をマウントするデバイスが生きている方のデバイスかどうかを確認する。

```
# cat /etc/fstab
...
/dev/disk/by-uuid/FFFF-FFF0 /boot/efi vfat defaults 0 1
#/dev/disk/by-uuid/FFFF-FFF1 /boot/efi vfat defaults 0 1

# ls -l /dev/disk/by-uuid/FFFF-FFF0
ls: cannot access '/dev/disk/by-uuid/FFFF-FFF0': No such file or directory

# ls -l /dev/disk/by-uuid/FFFF-FFF1
lrwxrwxrwx 1 root root ...... /dev/disk/by-uuid/FFFF-FFF0 -> ../../vdb1
```

上記のように、現在fstab に記載されている方のデバイスが障害となって見えない場合は、スペアの方のデバイスで`/boot/efi` をマウントするように変更する。
今回の例では、`/dev/disk/by-uuid/FFFF-FFF1` のコメントを解除して、`/dev/disk/by-uuid/FFFF-FFF0` をコメント化しておく。

* /etc/fstab
```
...
#/dev/disk/by-uuid/FFFF-FFF0 /boot/efi vfat defaults 0 1
/dev/disk/by-uuid/FFFF-FFF1 /boot/efi vfat defaults 0 1
...
```

変更が完了したら、マシンを再起動しましょう。

```
# shutdown -r now
```

再起動する場合は、生きている方のディスクに、しっかりとブートローダがインストールできている状態です。
もし、再起動してこない場合、Ubuntu インストール時にブートローダをもう方系のデバイスにコピーするのに失敗している可能性があります。

## 新しいディスクを交換する

```
# shutdown -h now
```

マシンが停止したら、故障したディスクを、新しいディスクに付け替えて起動します。

## ドライブレターを確認する
起動後、ドライブレターを確認します。
これは、復旧元と復旧先のデバイスを間違えると、データが破壊されてしまうので、確実に確認しておくようにします。

```
# ls -l /dev/vd*
brw-rw---- 1 root disk 252,  0 Jan  9 17:25 /dev/vda
brw-rw---- 1 root disk 252, 16 Jan  9 17:25 /dev/vdb
brw-rw---- 1 root disk 252, 17 Jan  9 17:25 /dev/vdb1
brw-rw---- 1 root disk 252, 18 Jan  9 17:25 /dev/vdb2
brw-rw---- 1 root disk 252, 19 Jan  9 17:25 /dev/vdb3
```

上記の出力結果の例では、`/dev/vda` が新しくつないだディスクで、`/dev/vdb` が生き残っているディスクであることを意味します。

## 復旧

```
# vgreduce --removemissing --force vg-boot
# vgreduce --removemissing --force vg-root
# pvdisplay
-> "[unknown]" なステータスの物理ボリュームがなくなる。
```

これいこう、新しくつないだデバイスにパーティション、LVM、ファイルシステムを作成していきます。
前の手順で確認した結果、これ以降の手順は、`/dev/vda` に対してパーティション、LVM、ファイルシステムを作成していく手順を示します。

```
# # /dev/vdb のパーティションを/dev/vda にコピーする
# sgdisk -R /dev/vda /dev/vdb

# partprobe
# ls -l /dev/vd*

# sgdisk -G /dev/vda
# dd if=/dev/vdb1 of=/dev/vda1
```

```
# pvcreate /dev/vda2 /dev/vda3
# vgextend vg-boot /dev/vda2
# vgextend vg-root /dev/vda3

```

ここで、一旦デバイスの状態を確認します。
```
# pvscan
  PV /dev/vdb3   VG vg-root         lvm2 [<23.00 GiB / 0    free]
  PV /dev/vda3   VG vg-root         lvm2 [<23.00 GiB / <23.00 GiB free]
  PV /dev/vdb2   VG vg-boot         lvm2 [508.00 MiB / 0    free]
  PV /dev/vda2   VG vg-boot         lvm2 [508.00 MiB / 508.00 MiB free]
  Total: 4 [46.98 GiB] / in use: 4 [46.98 GiB] / in no VG: 0 [0   ]
```

pvscan の結果を確認すると`/dev/vda3`, `/dev/vda2` が、まだ何も書き込まれず、100% Free な状態になっています。
このままでは、仮に今度、`/dev/vdb` が障害になった時、データが失われて復旧することができません。
新しく接続したデバイスにもデータをコピーするために、修復コマンドを実行します。

```
# lvconvert --repair vg-boot/lv-boot
Attempt to replace failed RAID images (requires full device resync)? [y/n]: y
  Faulty devices in vg-boot/lv-boot successfully replaced.

# lvconvert --repair vg-root/lv-root
Attempt to replace failed RAID images (requires full device resync)? [y/n]: y
  Faulty devices in vg-root/lv-root successfully replaced.
```

repair コマンドを実行したら、同期ステータスを確認します。

```
root@ubuntu:~# lvs -a -o +devices
  LV                 VG      Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert Devices
  lv-boot            vg-boot rwi-a-r--- 504.00m                                    100.00           lv-boot_rimage_0(0),lv-boot_rimage_1(0)
  [lv-boot_rimage_0] vg-boot iwi-aor--- 504.00m                                                     /dev/vda2(1)
  [lv-boot_rimage_1] vg-boot iwi-aor--- 504.00m                                                     /dev/vdb2(1)
  [lv-boot_rmeta_0]  vg-boot ewi-aor---   4.00m                                                     /dev/vda2(0)
  [lv-boot_rmeta_1]  vg-boot ewi-aor---   4.00m                                                     /dev/vdb2(0)
  lv-root            vg-root rwi-aor---  22.99g                                    10.85            lv-root_rimage_0(0),lv-root_rimage_1(0)
  [lv-root_rimage_0] vg-root Iwi-aor---  22.99g                                                     /dev/vda3(1)
  [lv-root_rimage_1] vg-root iwi-aor---  22.99g                                                     /dev/vdb3(1)
  [lv-root_rmeta_0]  vg-root ewi-aor---   4.00m                                                     /dev/vda3(0)
  [lv-root_rmeta_1]  vg-root ewi-aor---   4.00m                                                     /dev/vdb3(0)
```

`lv-boot` については、容量が少ないので、一瞬で修復と同期が完了しました。
`lv-root` は容量が大きいので、まだ10.85% 程しか同期できていません。
何度か`lvs` コマンドを繰り返し実行し、100% になるまで待ちましょう。  
  
```
root@ubuntu:~# lvs -a -o +devices
  LV                 VG      Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert Devices
  ......
  lv-root            vg-root rwi-aor---  22.99g                                    100.00           lv-root_rimage_0(0),lv-root_rimage_1(0)
  ......
```
同期が完了すると、上記の通りとなります。
これで、同期は完了です。
`pvscan` コマンドを実行すると、下記のようになります。

```
# pvscan
  PV /dev/vdb3   VG vg-root         lvm2 [<23.00 GiB / 0    free]
  PV /dev/vda3   VG vg-root         lvm2 [<23.00 GiB / 0    free]
  PV /dev/vdb2   VG vg-boot         lvm2 [508.00 MiB / 0    free]
  PV /dev/vda2   VG vg-boot         lvm2 [508.00 MiB / 0    free]
  Total: 4 [46.98 GiB] / in use: 4 [46.98 GiB] / in no VG: 0 [0   ]
```

* 参考  
[How to remove bad disk from LVM2 with the less data loss on other PVs?](https://serverfault.com/a/534283/253941)  

[7.3. RECOVERING FROM LVM MIRROR FAILURE](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/logical_volume_manager_administration/mirrorrecover)

