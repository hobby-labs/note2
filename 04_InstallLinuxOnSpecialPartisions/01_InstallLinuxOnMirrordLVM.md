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

インストールが完了したら、次の手順に進みます。

## セカンダリデバイスのEFI 領域をfstab にコメントとして残しておく
障害時に`/boot/efi` マウントポイントを復旧しやすくするために、スペア側のディスクの`/boot/efi` 領域をマウントする定義を書いておきましょう。

```
# uuid="$(blkid | grep -P '/dev/vdb1' | sed -e 's/.* UUID="\([^"]\+\)".*/\1/g')"
# printf '#/dev/disk/by-uuid/%s /boot/efi vfat defaults 0 1\n' "$uuid" >> /etc/fstab
```

上記コマンドを実行すると、下記のようにプライマリデバイス(/dev/vda)側の`/dev/efi` マウント定義と、セカンダリデバイス(/dev/vdb)側の`/dev/efi` マウント定義(コメント)の両方が定義されています。
そうすることで、もし`/dev/vda` に障害が発生してしまった時に、`/dev/vdb` 側のコメントを解除することで、スムーズに切り替えられるようになります。

# エラーから復旧する
片系のディスクが落ちて、そのディスクを付け替えた後の復旧手順。
`/dev/vda` が故障して、それを新しいやつに取り替えた後を想定した手順です。  
  
まず、`pvdisplay` コマンドでLVM 物理ボリュームの状態を確認します。
すると下記のような警告と、`PV Name` として`[unknown]` な物理ボリュームがあることがわかります。

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

## fstab に記載されている/boot/efi をマウントするデバイスが、生存している方のものか確認する
必要に応じて、fstab の/boot/efi 領域のマウントデバイスを変更する。
`blkid` コマンドを実行し、現在正常に動いているデバイスのEFI 領域のファイルシステム(vfat)のUUID を確認します。

```
# blkid
...
/dev/vdb1: UUID="FFFF-FFF1" TYPE="vfat" PARTLABEL="EFI System" PARTUUID="ffffffff-ffff-ffff-ffff-fffffffffff1"
...
```

## /etc/fstab の書き換え(必要に応じて)

次に`/etc/fstab` を確認し、`/boot/efi` 領域のデバイスが、`blkid`で確認したものと一致するか、確認します。

* /etc/fstab
```
/dev/disk/by-uuid/FFFF-FFF0 /boot/efi vfat defaults 0 1
#/dev/disk/by-uuid/FFFF-FFF1 /boot/efi vfat defaults 0 1
```

上記のように一致しない場合、`/etc/fstab` を書き換えます。
UUID が一致しないということは、今回の障害で使えなくなったディスクが、今まで`/boot/efi` 領域として実際に読まれていたということです、今回の障害で使えなくなってしまいました。
なので、今後も確実に起動できるよう`/etc/fstab` の`/boot/efi` 領域をマウントするデバイスを、現在生きている方のものに変えておきます。

* /etc/fstab
```
/dev/disk/by-uuid/FFFF-FFF0 /boot/efi vfat defaults 0 1
#/dev/disk/by-uuid/FFFF-FFF1 /boot/efi vfat defaults 0 1
↓ ↓ ↓
/dev/disk/by-uuid/FFFF-FFF1 /boot/efi vfat defaults 0 1
```

インストール時に、しっかりと両方のディスクにEFI 領域が作成されていれば、これで安全にマシンの再起動ができる状態になっています。

## 新しいディスクを交換する
新しいディスクをマシンに接続してください。
ディスクを接続したら下記コマンドを実行して、ディスクのパーティションを再読込してください。

```
# partprobe
```

ホットスワップに対応していない等、うまく認識しない環境の場合は、マシンを停止してからディスクを接続し、起動するなどして試してみてください。

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
新しくつないだディスク`/dev/vda` に対して、`/dev/vdb` の情報をコピーして復旧していきます。  
  
まず、ボリュームグループから障害が起きて正常に認識されなくなったLVM 物理ボリュームを取り外します。

```
# vgreduce --removemissing --force vg-boot
# vgreduce --removemissing --force vg-root
# pvdisplay
-> "[unknown]" なステータスの物理ボリュームがなくなる。
```

これいこう、新しくつないだデバイスにパーティション、LVM、ファイルシステムを作成していきます。
前の手順で確認した結果、これ以降の手順は、`/dev/vda` に対してパーティション、LVM、ファイルシステムを作成していく手順を示します。  
***これから先の手順は、手順を間違えるとシステムが2 度と起動しなくなる可能性やデータが損失するリスクがありますので注意してください。***

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

# 参考
* [How to remove bad disk from LVM2 with the less data loss on other PVs?](https://serverfault.com/a/534283/253941)  
* [7.3. RECOVERING FROM LVM MIRROR FAILURE](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/logical_volume_manager_administration/mirrorrecover)
