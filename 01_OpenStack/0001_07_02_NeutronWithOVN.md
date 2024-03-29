= OVN インストールドキュメント =

= 参考 =
; OpenStack and OVN Tutorial (Yoga)
: https://docs.openstack.org/neutron/yoga/admin/ovn/tutorial.html

; OVN Install Documentation (Yoga)
: https://docs.openstack.org/neutron/yoga/install/ovn/index.html

; OVN OpenStack Tutorial
: https://github.com/ovn-org/ovn/blob/main/Documentation/tutorials/ovn-openstack.rst

; 参考: HavanaのL3エージェントが起動しない
: https://groups.google.com/g/openstack-ja/c/_eypQ08epJI?pli=1

; CentOS7 ovs(Open vSwitch)+ovnのネットワーク設定方法
: https://metonymical.hatenablog.com/entry/2019/07/21/190302

; OpenStack Wallaby : Neutron OVN 設定 (Network ノード)
: https://www.server-world.info/query?os=Ubuntu_20.04&p=openstack_wallaby2&f=13

= Neutron インストール =

<syntaxhighlight lang="console">
openstack-controller-node01 ~# mysql
MariaDB [(none)]> CREATE DATABASE neutron;
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'p@ssw0rd';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'p@ssw0rd';

MariaDB [(none)]> SHOW GRANTS FOR 'neutron'@'localhost';
MariaDB [(none)]> SHOW GRANTS FOR 'neutron'@'%';
MariaDB [(none)]> quit
</syntaxhighlight>

<syntaxhighlight lang="text">
openstack-controller-node01 ~# . ./admin-openrc
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack user create --domain default --password=p@ssw0rd neutron
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | c848069aa2e044dca78baf4f73d22efe |
| name                | neutron                          |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack role add --project service --user neutron admin
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack service create --name neutron --description "OpenStack Networking" network
+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | OpenStack Networking             |
| enabled     | True                             |
| id          | ddcf7292e8414d98b7c7126bd2f83cf0 |
| name        | neutron                          |
| type        | network                          |
+-------------+----------------------------------+
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack endpoint create --region RegionOne network public http://openstack-controller-node01:9696
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | f296bb98d95b40be9afd9d3f0fd919f9        |
| interface    | public                                  |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | ddcf7292e8414d98b7c7126bd2f83cf0        |
| service_name | neutron                                 |
| service_type | network                                 |
| url          | http://openstack-controller-node01:9696 |
+--------------+-----------------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne network internal http://openstack-controller-node01:9696
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | d6538f395a674f2c84c284554655a888        |
| interface    | internal                                |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | ddcf7292e8414d98b7c7126bd2f83cf0        |
| service_name | neutron                                 |
| service_type | network                                 |
| url          | http://openstack-controller-node01:9696 |
+--------------+-----------------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne network admin http://openstack-controller-node01:9696
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | ce182403910c46efa1bc1ad8038d938b        |
| interface    | admin                                   |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | ddcf7292e8414d98b7c7126bd2f83cf0        |
| service_name | neutron                                 |
| service_type | network                                 |
| url          | http://openstack-controller-node01:9696 |
+--------------+-----------------------------------------+
</syntaxhighlight>

= OVN インストール =

以下のタイプのノードを含む、従来のアーキテクチャの本番用OpenStack デプロイメントツールに手動でインストール、または統合する際に必要なものについて説明します。

* Controller: REST, API 等のコントロールプレーンを実行します
* Network: L2, L3(routing), DHCP, Network サービスのメタデータエージェントを実行します。一般的に、プロバイダ(public)とプロジェクト(private) ネットワークをNAT 経由で接続しています
* Compute: Networking サービスのために、ハイパーバイザやL2 エージェントを走らせています

== OVN パッケージについて ==
OVN はOpen vSwitch(OVS) のversion 2.5 開始のときはOVS に含まれていました、v2.13 からOpen vSwitch から分断されました。
OVN のインテグレーションサービスは、現在Neutron ドライバーに含まれておりパッケージに含まれています。

== Controller ノード ==
各コントローラノードはOVS サービス(ovsdb-server)と<code>ovs-northd</code> サービスを起動しています。
が、1 つだけのインスタンス上で、<code>ovsdb-server</code> と<code>ovs-northd</code> サービスを起動することになります。
が、Active/Passive な構成を取ることもでき、実際の商用環境を稼働させるときは、選択したほうが良いかもしれません。<br /><br />

<code>openvswitch-ovn</code>, <code>networking-ovn</code> パッケージをインストールし、起動します。
OVN を使う場合は、OVN がDHCP をネイティブにサポートしているため、<code>neutron-dhcp-agent</code> はインストールしません。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y neutron-server neutron-plugin-ml2 neutron-l3-agent \
                                    neutron-metadata-agent neutron-openvswitch-agent \
                                    ovn-common ovn-host ovn-central ovn-controller-vtep ovn-ic ovn-ic-db ovn-docker
</syntaxhighlight>

今回はIPv6 を使用しないので、IPv6 Advertisement デーモンである<code>radvd</code> は無効化しておきます。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl stop radvd
openstack-controller-node01 ~# systemctl disable radvd
</syntaxhighlight>


<syntaxhighlight lang="console">
openstack-controller-node01 ~# # systemd を使う場合(ovsdb-server, ovs-vswitchd, ovsdb-server etc を自動起動設定する)
openstack-controller-node01 ~# systemctl enable ovs-vswitchd
openstack-controller-node01 ~# systemctl enable ovsdb-server
openstack-controller-node01 ~# systemctl enable ovn-northd
openstack-controller-node01 ~# systemctl enable ovn-ovsdb-server-nb
openstack-controller-node01 ~# systemctl enable ovn-ovsdb-server-sb
openstack-controller-node01 ~# systemctl enable ovn-ovsdb-server-ic-nb
openstack-controller-node01 ~# systemctl enable ovn-ovsdb-server-ic-sb
openstack-controller-node01 ~# systemctl enable ovn-controller
openstack-controller-node01 ~# systemctl enable ovn-controller-vtep
// 下記のような警告が出た場合は、他の処理によって、既に自動起動設定がされているので、
// そのまま次に進んで問題ありません。
// The unit files have no installation config (WantedBy=,...... This means they are not meant to be enabled using systemctl.

openstack-controller-node01 ~# # デーモンを再起動する。起動順序を考えるのが面倒なので、OS ごと再起動する。再起動後、再ログインする
openstack-controller-node01 ~# shutdown -r now

openstack-controller-node01 ~# # # ovs-ctl コマンドを使う場合(未検証)
openstack-controller-node01 ~# # /usr/share/openvswitch/scripts/ovs-ctl start --system-id="random"
openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl start_ovsdb
openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl start_nb_ovsdb
openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl start_sb_ovsdb
openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl start_northd
openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl start_controller
openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl start_controller_vtep
</syntaxhighlight>

<code>ovsdb-server</code> を設定していきます。
デフォルトで、<code>ovsdb-server</code> は、Unix ドメインソケットを使って、ローカルからのアクセスを許可するようになっていますが、Compute ノードからもアクセスできるように設定していきます。
コマンドでIP アドレスを指定していますが、コントローラノードの管理セグメントのIP アドレスを指定するようにしてください。
全部のインタフェースでListen したい場合は<code>0.0.0.0</code> を指定します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# ovn-nbctl set-connection ptcp:6641:192.168.2.71 -- set connection . inactivity_probe=60000
openstack-controller-node01 ~# ovn-sbctl set-connection ptcp:6642:192.168.2.71 -- set connection . inactivity_probe=60000
openstack-controller-node01 ~# # # VTEP を使っている場合
openstack-controller-node01 ~# ovs-appctl -t ovsdb-server ovsdb-server/add-remote ptcp:6640:192.168.2.71
</syntaxhighlight>

デーモンを再起動します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# shutdown -r now

openstack-controller-node01 ~# # systemctl restart ovsdb-server
openstack-controller-node01 ~# # systemctl restart ovn-northd

openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl restart_northd
openstack-controller-node01 ~# # /usr/share/ovn/scripts/ovn-ctl restart_ovsdb
</syntaxhighlight>

Networking サーバコンポーネントを設定します。このNetworking サービスは、ML2 ドライバとして、OVN を実現します。

* /etc/neutron/neutron.conf @ openstack-controller-node01
<syntaxhighlight lang="text">
[DEFAULT]
core_plugin = ml2
service_plugins = ovn-router
transport_url = rabbit://openstack:p@ssw0rd@openstack-controller-node01
auth_strategy = keystone

notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

# ......

[database]
# ......
connection = mysql+pymysql://neutron:p@ssw0rd@openstack-controller-node01/neutron
# ......

[keystone_authtoken]
# ......
www_authenticate_uri = http://openstack-controller-node01:5000
auth_url = http://openstack-controller-node01:5000
memcached_servers = openstack-controller-node01:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = p@ssw0rd
# ......

[oslo_concurrency]
# ......
lock_path = /var/lib/neutron/tmp
# ......

[nova]
auth_url = http://openstack-controller-node01:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = nova
password = p@ssw0rd
</syntaxhighlight>

* /etc/neutron/plugins/ml2/ml2_conf.ini @ openstack-controller-node01
<syntaxhighlight lang="text">
[ml2]
# ......
type_drivers = local,flat,vlan,geneve
tenant_network_types = geneve,vlan
mechanism_drivers = ovn
extension_drivers = port_security
overlay_ip_version = 4
# ......

[ml2_type_geneve]
# ......
vni_ranges = 1:65536
max_header_size = 38
# ......

[ml2_type_flat]
# ......
flat_networks = provider
# ......

[ml2_type_vlan]
# ......
network_vlan_ranges = enp9s0:1001:2000
# ......

[securitygroup]
# ......
enable_security_group = true
# firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
# ......

[ovn]
# ... TODO: Should [ovn] section put here not in ovn.ini? ...
ovn_nb_connection = tcp:192.168.2.71:6641
ovn_sb_connection = tcp:192.168.2.71:6642
ovn_l3_scheduler = leastloaded
ovn_metadata_enabled = True
# ......
</syntaxhighlight>

VLAN self-service network を有効化する場合、OVN version が2.11 以上であることを確認したうえで、<code>tenant_network_types</code> オプションに追加するようにしてください。
Network タイプリストの、先頭はの値はデフォルト値になります。<br />
また、IPv6 をすべてのオーバレイ(tunnel) ネットワークエンドポイントに使用する場合は、<code>overlay_ip_version</code> オプションに<code>6</code> を設定してください。<br /><br />

ネットワークセグメントを割り当てるために、<code>vni_range</code> を設定してください。
しかし、OVN は実際、この値を無視します。
Geneve ネットワークのID 範囲を定義するだけになります。
例えば、範囲を<code>5001:6000</code> とすれば、最大で1000 個のGeneve ネットワークを定義することになります。<br /><br />

任意項目である<code>network_vlan_ranges</code> は、VLAN を有効化してself-service ネットワークが、1 個から複数個の物理インタフェース上に存在することができます。
もし、物理インタフェースのみを指定した場合、特権をもつユーザだけが、VLAN ネットワークを管理することができます。
VLAN ID レンジを指定すると、特権を持たないユーザでもVLAN を管理できるようになります。<br />
例えば、<code>network_vlan_ranges = enp1s0:1001:2000</code> と指定すると、物理インタフェース<code>enp1s0</code> に、最小VLAN ID <code>1001</code>、最大VLAN ID <code>2000</code> でself-service VLAN ネットワークを設定できます。<br />
<code>network_vlan_ranges = enp1s0,enp3s0:1001:2000</code> と指定すると、物理インタフェース<code>enp1s0</code> に特権ユーザだけが管理できるVLAN セグメントを、<code>enp3s0</code> にVLAN ID 1001〜2000 のself-service VLAN ネットワークを設定できます。
複数個のインタフェースを指定する場合は、カンマ区切りで設定します。<br /><br />

# * /etc/neutron/ovn.ini
# <syntaxhighlight lang="text">
# [ovn]
# # ......
# ovn_nb_connection = tcp:192.168.2.71:6641
# ovn_sb_connection = tcp:192.168.2.71:6642
# ovn_l3_scheduler = leastloaded
# ovn_metadata_enabled = True
# # ......
# </syntaxhighlight>

# <code>ovn_nb_connection</code>, <code>ovn_sb_connection</code> のIP アドレスには、<code>ovsdb-server</code> サービスが起動しているコントローラノードをしていしてください。<br />
# <code>OVN_L3_SCHEDULER</code> には、<code>leastloaded</code> もしくは<code>chance</code> を指定してください。
# <code>leastloaded</code> を選択すると、最小のゲートウェイポートを持つコンピュートノードが選択されます。
# <code>change</code> を選択すると、ランダムで、コンピュートノードが選択されます。<br /><br />

# * /etc/neutron/neutron_ovn_metadata_agent.ini
# <syntaxhighlight lang="text">
# [DEFAULT]
# # ......
# nova_metadata_host = 192.168.2.71
# metadata_proxy_shared_secret = metadata_secret
# # ......
# 
# [ovs]
# # ......
# ovsdb_connection = tcp:192.168.2.71:6640
# # ......
# 
# [ovn]
# # ......
# ovn_sb_connection = tcp:192.168.2.71:6642
# # ......
# 
# [agent]
# # ......
# root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf
# </syntaxhighlight>
# // [ovn], [agent] セクションは最終行に新規追加


# * /etc/sysconfig/openvswitch
# <syntaxhighlight lang="text">
# 
# </syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# ovs-vsctl set open . external-ids:ovn-cms-options=enable-chassis-as-gw
</syntaxhighlight>

= neutron のDB テーブル作成 =

<syntaxhighlight lang="text">
openstack-controller-node01 ~# su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
                                   --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
</syntaxhighlight>

== Layer 3 エージェントを設定する ==
OVN を使う場合は、特に設定は不要です。

= Networking サービスを使うためのCompute サービス設定 =
<code>/etc/nova/nova.conf</code> ファイルを設定します。

* /etc/nova/nova.conf @ openstack-controller-node01, dev-compute01, dev-compute02, dev-compute03
<syntaxhighlight lang="text">
[neutron]
auth_url = http://openstack-controller-node01:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = neutron
password = p@ssw0rd
......
</syntaxhighlight>

同じく<code>nova.conf</code>に、controller ノードに対してのみ、metadata proxy の設定を行います。<br />
// TODO: 要確認

* /etc/nova/nova.conf @ openstack-controller-node01
<syntaxhighlight lang="text">
[neutron]
......
service_metadata_proxy = true
metadata_proxy_shared_secret = p@ssw0rd
</syntaxhighlight>

= 各サービスの再起動 =

<code>ovn-northd</code> 各サービスを再起動します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# #/usr/share/ovn/scripts/ovn-ctl restart_ovsdb
openstack-controller-node01 ~# #/usr/share/ovn/scripts/ovn-ctl restart_northd
openstack-controller-node01 ~# #/usr/share/ovn/scripts/ovn-ctl restart_nb_ovsdb
openstack-controller-node01 ~# #/usr/share/ovn/scripts/ovn-ctl restart_sb_ovsdb
openstack-controller-node01 ~# #/usr/share/ovn/scripts/ovn-ctl restart_controller

openstack-controller-node01 ~# # systemd を使う場合(ovsdb-server, ovs-vswitchd, ovsdb-server を起動する)
openstack-controller-node01 ~# systemctl restart ovs-vswitchd
openstack-controller-node01 ~# systemctl restart ovsdb-server
openstack-controller-node01 ~# systemctl restart ovn-ovsdb-server-nb
openstack-controller-node01 ~# systemctl restart ovn-ovsdb-server-sb
openstack-controller-node01 ~# systemctl restart ovn-northd
openstack-controller-node01 ~# systemctl restart ovn-controller
openstack-controller-node01 ~# systemctl restart ovn-controller-vtep
</syntaxhighlight>

= Network node =
OVN を使ったデプロイは、Network ノードを必要としません。
なぜなら、外部ネットワークとの接続性やルーティングはコンピュートノードで行われるからです。

= Compute node =
Compute ノードの設定を行っていきます。
OVS と<code>ovn-controller</code> サービスを起動しています。
<code>ovn-controller</code> サービスは、従来のOVS レイヤ2 エージェントの代わりとなるものです。<br /><br />

<syntaxhighlight lang="console">
openstack-compute-node01 ~# apt-get install -y neutron-openvswitch-agent ovn-common ovn-host ovn-central ovn-controller-vtep
</syntaxhighlight>

<code>openvswitch-ovn</code>, <code>networking-ovn</code> を起動します。

* computenodes
<syntaxhighlight lang="console">
openstack-compute-node01 ~# # /usr/share/openvswitch/scripts/ovs-ctl start --system-id="random"

openstack-compute-node01 # systemctl enable ovs-vswitchd
openstack-compute-node01 # systemctl enable ovsdb-server
openstack-compute-node01 # systemctl enable ovn-northd
openstack-compute-node01 # systemctl enable ovn-ovsdb-server-nb
openstack-compute-node01 # systemctl enable ovn-ovsdb-server-sb
openstack-compute-node01 # systemctl enable ovn-controller
openstack-compute-node01 # systemctl enable ovn-controller-vtep

openstack-compute-node01 # shutdown -r now
</syntaxhighlight>

OVS サービスの設定を行います。
設定には、<code>ovs-vsctl</code> コマンドを使い、<code>ovn-remote=</code> のIP アドレスには、コントローラノード<code>openstack-controller-node01</code> のIP アドレスを指定します。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# ovs-vsctl set open . external-ids:ovn-remote=tcp:192.168.2.71:6642
</syntaxhighlight>

1 つ以上のoverlay network プロトコルを有効化します。
最小で、OVN の要件として<code>geneve</code>、VTEP ゲートウェイを使うデプロイメントとして、<code>vxlan</code> プロトコルを有効化します。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# ovs-vsctl set open . external-ids:ovn-encap-type=geneve,vxla
</syntaxhighlight>

また、vtep を使っている場合は、ovn-encap-ip も指定します。
<syntaxhighlight lang="console">
openstack-compute-node01 ~# ovs-vsctl set open . external-ids:ovn-encap-ip=192.168.2.71
</syntaxhighlight>

overlay network のローカルエンドポイントネットワークのIP アドレスを設定します。
IP アドレスには、コンピュートノードのoverlay network インタフェースのIP アドレスを指定してください。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# ovs-vsctl set open . external-ids:ovn-encap-ip=192.168.2.72
</syntaxhighlight>

次に、neutron の設定を行います。

* /etc/neutron/neutron.conf @ openstack-compute-node01
<syntaxhighlight lang="text">
[DEFAULT]
......
transport_url = rabbit://openstack:p@ssw0rd@openstack-controller-node01
auth_strategy = keystone
......

[keystone_authtoken]
www_authenticate_uri = http://openstack-controller-node01:5000
auth_url = http://openstack-controller-node01:5000
memcached_servers = openstack-controller-node01:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = p@ssw0rd
......

[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
......

[database]
#connection = sqlite:////var/lib/neutron/neutron.sqlite  # <- コメントアウトします
</syntaxhighlight>

* /etc/neutron/l3_agent.ini @ openstack-compute-node01
<syntaxhighlight lang="console">
[DEFAULT]
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
</syntaxhighlight>

* /etc/nova/nova.conf @ openstack-compute-node01
<syntaxhighlight lang="text">
[DEFAULT]
......
# Added vif parameters to prevent https://ask.openstack.org/en/question/26938/virtualinterfacecreateexception-virtual-interface-creation-failed/
# Or see: https://web.archive.org/web/20201021171630/https://ask.openstack.org/en/question/26938/virtualinterfacecreateexception-virtual-interface-creation-failed/
vif_plugging_is_fatal = false
vif_plugging_timeout = 0
......

[neutron]
auth_url = http://openstack-controller-node01:5000
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = neutron
password = p@ssw0rd
......
</syntaxhighlight>

<code>ovn-controller</code> サービスを起動します。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# # /usr/share/ovn/scripts/ovn-ctl restart_controller
  or
openstack-compute-node01 ~# systemctl restart ovn-controller
</syntaxhighlight>

#ovs の現在の状態を確認します。
#<syntaxhighlight lang="console">
#openstack-compute-node01 ~# ovn-sbctl show
#</syntaxhighlight>

