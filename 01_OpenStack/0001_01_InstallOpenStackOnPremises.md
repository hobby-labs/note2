= 前提事項 =

VM 環境にOpenStack をインストールする場合は、MAC アドレスフィルタリングをOFF にする必要があります。

; Environment
: https://docs.openstack.org/install-guide/environment.html

OpenStack をインストールすると、様々なコンポーネントのパスワードが設定されます。
パスワードの種類としては、以下ページの書かれているものがあります。

; Security
: https://docs.openstack.org/install-guide/environment-security.html

OpenStack には大きく分けて、Provider Network(インターネットに接続できるセグメント)と、Management Network(管理セグメント)に分けられる。
違いの図は以下のページにあります。

; Host networking
: https://docs.openstack.org/install-guide/environment-networking.html

* openstack-controller-node01 - Controller node
* openstack-compute-node01 - Compute node
* openstack-block-storage-node01 - Blocl storage node
* openstack-object-storage-node01 - Object storage node

{| class="wikitable"
|+ align="top" style="text-align: left" |''OpenStack 構成ノード一覧''
|-
! ホスト名
! 役割
! Provider Network IP(インタフェース名, 接続先ブリッジ)
! Management Network IP(インタフェース名, 接続先ブリッジ)
! 備考
|-
| openstack-controller-node01
| Controller node
| 192.168.1.71(enp1s0, master br0)
| 192.168.2.71(enp9s0, master br100)
| Provider Network, Management Netowrk の2 NIC を用意
|-
| openstack-compute-node01
| Compute node
| 192.168.1.72(enp1s0, master br0)
| 192.168.2.72(enp9s0, master br100)
| Provider Network, Management Netowrk の2 NIC を用意
|-
| openstack-block-storage-node01
| Blocl storage node
| -
| 192.168.2.73
| Management Netowrk のみの1 NIC を用意。このノードは任意です
|-
| openstack-object-storage-node01
| Object storage node
| -
| 192.168.2.74
| Management Netowrk のみの1 NIC を用意。このノードは任意です
|-
| openstack-object-storage-node02
| Object storage node
| -
| 192.168.2.75
| Management Netowrk のみの1 NIC を用意。このノードは任意です
|}

= ホスト側の設定 =

== vxlan の設定 ==
vxlan 周りの設定は、<code>https://github.com/tsuna-server/vxlan-builder</code> を使うことにします。

* node01, node02, node03
<syntaxhighlight lang="console">
# cd /opt
# git clone https://github.com/tsuna-server/vxlan-builder
# cd vxlan-builder
</syntaxhighlight>

<code>vxlan.conf</code> を設定します。

* node01
<syntaxhighlight lang="text">
HOST_BRIDGE_INTERFACE="br0"
VXLAN_GW_INNER_IP="192.168.2.254/24"
VXLAN_GW_OUTER_IP="192.168.1.254/24"
VXLAN_NAT_SOURCE_IP_TO_INTERNET="192.168.2.0/24"
VXLAN_NAT_SOURCE_IP_TO_VXLAN="192.168.1.0/24"
</syntaxhighlight>

* node02
<syntaxhighlight lang="text">
HOST_BRIDGE_INTERFACE="br0"
VXLAN_GW_INNER_IP="192.168.2.253/24"
VXLAN_GW_OUTER_IP="192.168.1.253/24"
VXLAN_NAT_SOURCE_IP_TO_INTERNET="192.168.2.0/24"
VXLAN_NAT_SOURCE_IP_TO_VXLAN="192.168.1.0/24"
</syntaxhighlight>

* node03
<syntaxhighlight lang="text">
HOST_BRIDGE_INTERFACE="br0"
VXLAN_GW_INNER_IP="192.168.2.252/24"
VXLAN_GW_OUTER_IP="192.168.1.252/24"
VXLAN_NAT_SOURCE_IP_TO_INTERNET="192.168.2.0/24"
VXLAN_NAT_SOURCE_IP_TO_VXLAN="192.168.1.0/24"
</syntaxhighlight>

スクリプトを実行して、VXLAN 環境を構築します。

<syntaxhighlight lang="console">
node0[123] ~# /opt/vxlan-builder/set_vxlan_env.sh
</syntaxhighlight>

しかし、これだけではOS 再起動時にVXLAN 環境はリセットされてしまいます。それを防ぐための手順を実施していきます。<br /><br />

systemd サービスを登録します。<br />
まずは、<code>/etc/systemd/system/</code> ディレクトリ配下に、systemd ファイルを作成します。

* /etc/systemd/system/custom-vxlan.service @ node0[123]
<syntaxhighlight lang="text">
[Unit]
Description = Custom VXLAN Setting Service

[Service]
ExecStart = /opt/vxlan-builder/set_vxlan_env.sh
Type = oneshot
Requires = network.target

[Install]
WantedBy = multi-user.target
</syntaxhighlight>

ファイルを作成したら、登録されていることを確認します。

<syntaxhighlight lang="console">
# systemctl list-unit-files --type=service | grep custom-vxlan
custom-vxlan.service                   disabled        enabled
</syntaxhighlight>

確認できたら、状態をenable に設定します。

<syntaxhighlight lang="console">
# systemctl enable custom-vxlan.service
</syntaxhighlight>

これでOS 再起動時に自動的にVXLAN 環境も構築されるようになりました。

== netplan の設定 ==
* /etc/netplan/00-installer-config.yaml @ node01
<syntaxhighlight lang="yaml">
network:
  ethernets:
    eno1:
      dhcp4: no
      dhcp6: no
  bridges:
    br0:
      interfaces: [eno1]
      dhcp4: no
      dhcp6: no
      addresses: [192.168.1.21/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
      routes:
      - to: 192.168.2.0/24
        via: 192.168.1.254
    br100:
      dhcp4: no
      dhcp6: no
</syntaxhighlight>

* /etc/netplan/00-installer-config.yaml @ node02
<syntaxhighlight lang="yaml">
network:
  ethernets:
    eno1:
      dhcp4: no
      dhcp6: no
  bridges:
    br0:
      interfaces: [eno1]
      dhcp4: no
      dhcp6: no
      addresses: [192.168.1.22/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
      routes:
      - to: 192.168.2.0/24
        via: 192.168.1.253
    br100:
      dhcp4: no
      dhcp6: no
</syntaxhighlight>

* /etc/netplan/00-installer-config.yaml @ node03
<syntaxhighlight lang="yaml">
network:
  ethernets:
    eno1:
      dhcp4: no
      dhcp6: no
  bridges:
    br0:
      interfaces: [eno1]
      dhcp4: no
      dhcp6: no
      addresses: [192.168.1.23/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
      routes:
      - to: 192.168.2.0/24
        via: 192.168.1.252
    br100:
      dhcp4: no
      dhcp6: no
</syntaxhighlight>

= Controller Node =
== ネットワークインタフェースの設定 ==

* /etc/netplan/00-installer-config.yaml @ openstack-controller-node01
<syntaxhighlight lang="yaml">
network:
  ethernets:
    enp1s0:
      dhcp4: no
      dhcp6: no
    enp9s0:
      dhcp4: no
      dhcp6: no
      addresses:
        - 192.168.2.71/24
      gateway4: 192.168.2.254
      mtu: 1450
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
  version: 2
</syntaxhighlight>

次に、<code>/etc/hosts</code> に各ノードの名前解決が出いるように、IP アドレスを登録します。
登録するIP アドレスはManagement ネットワークのIP を設定します。

* /etc/hosts
<syntaxhighlight lang="text">
192.168.2.71    openstack-controller-node01
192.168.2.72    openstack-compute-node01
192.168.2.73    openstack-block-storage-node01
192.168.2.74    openstack-object-storage-node01
192.168.2.75    openstack-object-storage-node02
</syntaxhighlight>

= Compute Node =
== ネットワークインタフェースの設定 ==

* /etc/netplan/00-installer-config.yaml @ openstack-compute-node01
<syntaxhighlight lang="yaml">
network:
  ethernets:
    enp1s0:
      dhcp4: no
      dhcp6: no
    enp9s0:
      dhcp4: no
      dhcp6: no
      addresses:
        - 192.168.2.72/24
      gateway4: 192.168.2.253
      mtu: 1450
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
  version: 2
</syntaxhighlight>

* /etc/hosts
<syntaxhighlight lang="text">
192.168.2.71    openstack-controller-node01
192.168.2.72    openstack-compute-node01
192.168.2.73    openstack-block-storage-node01
192.168.2.74    openstack-object-storage-node01
192.168.2.75    openstack-object-storage-node02
</syntaxhighlight>

= Block Storage Node =

* /etc/netplan/00-installer-config.yaml @ openstack-object-storage-node01
<syntaxhighlight lang="yaml">
network:
  ethernets:
    enp1s0:
      dhcp4: no
      dhcp6: no
      addresses:
        - 192.168.2.73/24
      gateway4: 192.168.2.252
      mtu: 1450
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
  version: 2
</syntaxhighlight>

* /etc/hosts
<syntaxhighlight lang="text">
192.168.2.71    openstack-controller-node01
192.168.2.72    openstack-compute-node01
192.168.2.73    openstack-block-storage-node01
192.168.2.74    openstack-object-storage-node01
192.168.2.75    openstack-object-storage-node02
</syntaxhighlight>

= Object Storage Node 01 =

* /etc/netplan/00-installer-config.yaml
<syntaxhighlight lang="yaml">
network:
  ethernets:
    enp1s0:
      dhcp4: no
      dhcp6: no
      addresses:
        - 192.168.2.74/24
      gateway4: 192.168.2.254
      mtu: 1450
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
  version: 2
</syntaxhighlight>

* /etc/hosts
<syntaxhighlight lang="text">
192.168.2.71    openstack-controller-node01
192.168.2.72    openstack-compute-node01
192.168.2.73    openstack-block-storage-node01
192.168.2.74    openstack-object-storage-node01
192.168.2.75    openstack-object-storage-node02
</syntaxhighlight>

= Object Storage Node 02 =

* /etc/netplan/00-installer-config.yaml
<syntaxhighlight lang="yaml">
network:
  ethernets:
    enp1s0:
      dhcp4: no
      dhcp6: no
      addresses:
        - 192.168.2.75/24
      gateway4: 192.168.2.253
mtu: 1450
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
  version: 2
</syntaxhighlight>

* /etc/hosts
<syntaxhighlight lang="text">
192.168.2.71    openstack-controller-node01
192.168.2.72    openstack-compute-node01
192.168.2.73    openstack-block-storage-node01
192.168.2.74    openstack-object-storage-node01
192.168.2.75    openstack-object-storage-node02
</syntaxhighlight>

= NTP =

; Network Time Protocol (NTP)
: https://docs.openstack.org/install-guide/environment-ntp.html

* openstack-controller-node01, openstack-compute-node01,openstack-block-storage-node01,openstack-object-storage-node01,openstack-object-storage-node02
<syntaxhighlight lang="console">
# apt-get install -y chrony
</syntaxhighlight>

NTP のサーバとして稼働させる<code>openstack-controller-node01</code> の設定ファイルには、下記のように記載します。

* /etc/chrony/chrony.conf @ openstack-controller-node01
<syntaxhighlight lang="text">
allow 192.168.2.0/24
</syntaxhighlight>

NTP のクライアントとして稼働させるコントローラノード以外の設定ファイルには、下記のように記載します。

* /etc/chrony/chrony.conf @ openstack-compute-node01,openstack-block-storage-node01,openstack-object-storage-node01,openstack-object-storage-node02
<syntaxhighlight lang="text">
server openstack-controller-node01 iburst
</syntaxhighlight>

// 今回、NTP サーバは、デフォルトで設定されていたpool(ntp.ubuntu.com, 0.ubuntu.pool.ntp.org, ...) を使用することにしました。<br />
// なので、pool セクションはserver セクションで指定されている値は特に変更していません。<br />
// より性格な時刻同期を性能を求める場合は、strutum の値の低いNTP サーバを指定するようにしてください。

* openstack-compute-node01,openstack-block-storage-node01,openstack-object-storage-node01,openstack-object-storage-node02
<syntaxhighlight lang="console">
# systemctl restart chrony.service
# systemctl enable chrony.service
</syntaxhighlight>

= chrony の時刻同期チェック =

<code>chronyc<?code> コマンドを実行して、時刻同期サーバの一覧をチェックします。

* All servers
<syntaxhighlight lang="console">
# chronyc sources
210 Number of sources = 8
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^- alphyn.canonical.com          2  10   377   369  -7360us[-5858us] +/-  157ms
^- pugot.canonical.com           2  10   375   977  -9143us[-7642us] +/-  152ms
^- golem.canonical.com           2  10   377   408    -17ms[  -15ms] +/-  161ms
^- chilipepper.canonical.com     2  10   377   998  -8159us[-6658us] +/-  155ms
^* sh03.paina.net                2  10   277   247  -4989us[-3486us] +/-   76ms
^- ntp4.0x00.lv                  2  10   377   567  +3720us[+5221us] +/-  170ms
^+ 199-188-64-12.dhcp.imonc>     2  10   377   459  -1932us[ -430us] +/-  115ms
^+ stratum2-1.NTP.TechFak.N>     2  10   377   704   -963us[ +539us] +/-  135ms
</syntaxhighlight>

上記のように、一覧が表示され(一覧は環境ごとに異なる)、同期されているサーバの先頭に<code>*</code> がついていればOKです。

= SQL Database =
OpenStack に関するデータを格納するために、Controller ノードでSQL DB を準備します。
一般的にOpenStack で利用されるDB はMariaDB かMySQL ですが、それ以外のDB にも対応しています。

* openstack-controller-node01
<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y mariadb-server python3-pymysql
</syntaxhighlight>

<code>/etc/mysql/mariadb.conf.d/99-openstack.cnf</code> ファイルを新規作成し、以下の内容を記述します。
<code>bind-address</code> には、管理ネットワークセグメントの、Controller ノードのIP アドレスを指定してください。

* /etc/mysql/mariadb.conf.d/99-openstack.cnf @ openstack-controller-node01
<syntaxhighlight lang="console">
[mysqld]
bind-address = 192.168.2.71

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
</syntaxhighlight>

設定が完了したら、デーモンを再起動します。

* openstack-controller-node01
<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl restart mariadb.service
openstack-controller-node01 ~# systemctl enable mariadb.service
</syntaxhighlight>

<code>mysql_secure_installation</code> を実行して、セキュリティ設定を行います。
この中で、DB のroot パスワード設定も行います。
また、その他の質問に対しては、基本Yes で大丈夫です。

* openstack-controller-node01
<syntaxhighlight lang="console">
openstack-controller-node01 ~# mysql_secure_installation
</syntaxhighlight>

= Message queue =
; Message queue
: https://docs.openstack.org/install-guide/environment-messaging.html

OpenStack では、Message Queue をService 間の操作の調整や状態の通知に利用されます。
今回は、多くのディストリビューションでサポートされているRabbidMQ を使用することにします。<br /><br />

Message Queue サービスはController ノードで起動していることを要求します。

* openstack-controller-node01
<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y rabbitmq-server
openstack-controller-node01 ~# rabbitmqctl add_user openstack "p@ssw0rd"
Adding user "openstack" ...
openstack-controller-node01 ~# rabbitmqctl set_permissions openstack ".*" ".*" ".*"
Setting permissions for user "openstack" in vhost "/" ...
</syntaxhighlight>

= Memcached =

; Memcached
: https://docs.openstack.org/install-guide/environment-memcached.html

認証用のトークンを保管するために、Memcached が使用されます。
Memcached はコントローラノードで起動します。
セキュリティ強度を高めるために、ファイアウォール、認証、暗号等を組み合わせて使う必要があります。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y memcached python3-memcache
</syntaxhighlight>

<code>/etc/memcached.conf</code> を編集して、service management IP アドレスを設定します。
これは、管理セグメントを通して、他ノードがMemcached にアクセスできるように設定します。

* /etc/memcached.conf
<syntaxhighlight lang="console">
# ......
-l 192.168.2.71
# ......
</syntaxhighlight>

設定が完了したら、memcached を再起動します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl enable --now memcached
</syntaxhighlight>

= Etcd=

; Etcd
: https://docs.openstack.org/install-guide/environment-etcd.html

OpenStack サービスは、Etcd を多用します。
Etcd はkey/value ストアで、排他ロックをかけられ、サービスの生存状態なども追跡できます。
これは、コントローラノードでインストールします。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y etcd
</syntaxhighlight>

<code>/etc/default/etcd</code> ファイルを編集し、各変数を下記のように設定します。
設定を変更するする変数としては<code>ETCD_INITIAL_CLUSTER</code>, <code>ETCD_INITIAL_ADVERTISE_PEER_URLS</code>, <code>ETCD_ADVERTISE_CLIENT_URLS</code>, <code>ETCD_LISTEN_CLIENT_URLS</code> で、管理セグメントからアクセスするための設定になります。

* /etc/default/etcd
<syntaxhighlight lang="text">
ETCD_NAME="openstack-controller-node01"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER="openstack-controller-node01=http://192.168.2.71:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.2.71:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.2.71:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.2.71:2379"
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl enable --now etcd
</syntaxhighlight>

= OpenStack パッケージ =

; OpenStack packages
: https://docs.openstack.org/install-guide/environment-packages.html

Ubuntu 20.04 LTS の場合は、以下のコマンドでapt リポジトリを追加します。

* All servers
<syntaxhighlight lang="console">
# add-apt-repository cloud-archive:xena
# #add-apt-repository cloud-archive:wallaby
# #add-apt-repository cloud-archive:victoria
# apt-get update && apt-get -y dist-upgrade
</syntaxhighlight>

リポジトリの追加が完了したら、OpenStack クライアントとpython-pip のインストールを行います。

* All servers (Ubuntu 20.04 の場合)
<syntaxhighlight lang="console">
# apt-get install -y python3-openstackclient python3-pip
</syntaxhighlight>

= Install OpenStack =

; OpenStack Releases
: https://releases.openstack.org/

; OpenStack Victoria Installation Guides
: https://docs.openstack.org/victoria/install/

; Install OpenStack services
: https://docs.openstack.org/install-guide/openstack-services.html

"Install OpenStack services" ページの"Minimal deployment for Victoria" を参考に、OpenStack をインストールしていきます。

= 参考 =
; OpenStack Installation Guide
: https://docs.openstack.org/install-guide/
