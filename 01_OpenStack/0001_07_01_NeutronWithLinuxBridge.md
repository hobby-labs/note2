= Networking サービスのインストール =

; Install and configure for Ubuntu (Neutron)
: https://docs.openstack.org/neutron/yoga/install/install-ubuntu.html

OpenStack のNetworking サービスは、インタフェースをOpenStack サービスにアタッチするためのものです。
このプラグインシステムは、異なるネットワークの装置とソフトを包括することを可能とします。<br /><br />

Networking サービスは、以下のものが含まれています。

; neutron-server
: 適切なOpenStack ネットワークプラグインへリクエストを許可、転送するためのプラグインです

; OpenStack ネットワークプラグインとエージェント
: ネットワークポートと、ネットワークサブネット作成、IP アドレスの提供を行います。これらは、異なるベンダと技術に依存しており、Cisco virtual and physical switches, NEC OpenFlos, Open vSwitch, Linux bridging, VMWare NSX といった、ベンダにプラグインを提供しています

; Messaging queue
: だいたいのOpenStack インストール時に、neutron-server とエージェント間でデータ送受信に使われるものです。また、プラグインの状態を保管するためのデータベースに近いものとして利用されます

OpenStack Networking サービスは、インスタンスに対するネットワーク接続性を提供するものになります。

= Networking (neutron) concepts =

; Networking (neutron) concepts
: https://docs.openstack.org/neutron/wallaby/install/concepts.html

OpenStack Networking (neutron) は、OpenStack の仮想ネットワークインフラストラクチャ(VNI)と、物理ネットワークインフラストラクチャ(PNI)の、すべてのネットワークの側面を管理します。
Networking サービスは、FireWall やVPN といった、追加の機能も提供します。<br /><br />

Networking は、オブジェクトの抽象化として、ネットワーク、サブネット、ルーティングを提供します。<br /><br />

以下、説明を割愛。

= Neutron のインストール =

; Install and configure controller node
: https://docs.openstack.org/neutron/wallaby/install/controller-install-ubuntu.html

コントローラノード<code>openstack-controller-node01</code> に、Neutron をインストールします。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# mysql
MariaDB [(none)]> CREATE DATABASE neutron;
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'p@ssw0rd';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'p@ssw0rd';
MariaDB [(none)]> quit
</syntaxhighlight>

管理者の認証情報をロードします。

<syntaxhighlight lang="text">
openstack-controller-node01 ~# . ./admin-openrc
</syntaxhighlight>

neutron ユーザを作成します。

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

neutron ユーザを管理者として追加します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack role add --project service --user neutron admin
</syntaxhighlight>

neutron サービスエンティティを追加します。

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

== Network オプションの設定 ==
先に述べたように、OpenStack では2 つのネットワークを提案しています。

* オプション1: インスタンスがプロバイダネットワークのみにアタッチを提供するだけの、シンプルなネットワーク構成
* オプション2: オプション1 に加えて、インスタンスがセルフサービスネットワークに接続できる機能を提供します。管理権限を持たないユーザがセルフサービスネットワークにルーターを設置したり、プロバイダネットワークへアタッチすることができます

今回は、オプション2 のネットワーク構成を構築していきたいと思います。

= Self-service ネットワークの設定 =

; Networking Option 2: Self-service networks
: https://docs.openstack.org/neutron/wallaby/install/controller-install-option2-ubuntu.html

== コンポーネントインストール ==
コントローラノードに、コンポーネントをインストールします。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y neutron-server neutron-plugin-ml2 \
                                   neutron-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent \
                                   neutron-metadata-agent
</syntaxhighlight>

== サービスコンポーネントの設定 ==
<code>/etc/neutron/neutron.conf</code> ファイルを編集します。

* /etc/neutron/neutron.conf @ openstack-controller-node01
<syntaxhighlight lang="console">
[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = true
transport_url = rabbit://openstack:p@ssw0rd@openstack-controller-node01
auth_strategy = keystone
......

[database]
connection = mysql+pymysql://neutron:p@ssw0rd@openstack-controller-node01/neutron
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
</syntaxhighlight>

# == Nova への通知設定 ==
# ##### 本手順は、公式ドキュメントにはない手順 ###### <br />
# 
# * /etc/neutron/neutron.conf @ openstack-controller-node01
# <syntaxhighlight lang="text">
# [nova]
# # ...
# auth_url = http://openstack-controller-node01:5000
# auth_type = password
# project_domain_name = Default
# user_domain_name = Default
# region_name = RegionOne
# project_name = service
# username = nova
# password = nova
# </syntaxhighlight>

== Modular Layer 2 (ML2) プラグインの設定 ==
ML2 プラグインは、インスタンスに対して、Linux 仮想レイヤ2 機能(ブリッジとスイッチ)を提供します。

* /etc/neutron/plugins/ml2/ml2_conf.ini @ openstack-controller-node01
<syntaxhighlight lang="console">
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

#type_drivers = local,flat,vlan,gre,vxlan,geneve  # <- デフォルトで定義されているtype_drivers はコメントアウトする
......

[ml2_type_flat]
flat_networks = provider
......

[ml2_type_vxlan]
vni_ranges = 1:1000
......

[securitygroup]
enable_ipset = true
</syntaxhighlight>

== Linux bridge エージェントの設定 ==
Linux bridge エージェントは、インスタンスにL2 仮想ネットワークインフラを提供し、セキュリティグループを操作します。

* /etc/neutron/plugins/ml2/linuxbridge_agent.ini @ openstack-controller-node01
<syntaxhighlight lang="text">
[linux_bridge]
physical_interface_mappings = provider:enp1s0
......

[vxlan]
enable_vxlan = true
local_ip = 192.168.2.71  # <- コントローラノードの、tenant network のIP アドレスを指定する
l2_population = true
......

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
......

</syntaxhighlight>

Linux カーネルが、ネットワークブリッジをサポートしているか調べるために、<code>net.bridge.bridge-nf-call-iptables</code>, <code>net.bridge.bridge-nf-call-ip6tables</code> のパラメータが1 になっていることを確認してください。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# sysctl -a | grep net.bridge.bridge-nf-call-
</syntaxhighlight>

何も表示されない場合は、<code>br_netfilter</code> カーネルモジュールをロードします。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# modprobe br_netfilter
openstack-controller-node01 ~# cat << 'EOF' > /etc/sysctl.d/br_netfilter.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

openstack-controller-node01 ~# sysctl --system
</syntaxhighlight>

== Layer 3 エージェントを設定する ==
L3 エージェントは、self-service 仮想ネットワークにルーティングとNAT サービスを提供します。
<code>/etc/neutron/l3_agent.ini</code> ファイルを下記のように変更します。

* /etc/neutron/l3_agent.ini @ openstack-controller-node01
<syntaxhighlight lang="text">
[DEFAULT]
interface_driver = linuxbridge
......
</syntaxhighlight>

== DHCP エージェントの設定 ==

* /etc/neutron/dhcp_agent.ini @ openstack-controller-node01
<syntaxhighlight lang="text">
[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
......
</syntaxhighlight>

== メタデータエージェントの設定 ==
インスタンスに、認証情報を渡します。

* /etc/neutron/metadata_agent.ini @ openstack-controller-node01
<syntaxhighlight lang="text">
[DEFAULT]
nova_metadata_host = openstack-controller-node01
metadata_proxy_shared_secret = p@ssw0rd
......
</syntaxhighlight>

== Networking サービスを使うためのCompute サービス設定 ==
<code>/etc/nova/nova.conf</code> ファイルを設定します。

* /etc/nova/nova.conf @ openstack-controller-node01
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
service_metadata_proxy = true
metadata_proxy_shared_secret = p@ssw0rd
......
</syntaxhighlight>

= 仕上げ =
DB を作成します。

<syntaxhighlight lang="text">
openstack-controller-node01 ~# su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
                                   --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
</syntaxhighlight>

Compute API、Networking サービスを再起動します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl restart nova-api
openstack-controller-node01 ~# systemctl restart neutron-server
openstack-controller-node01 ~# systemctl restart neutron-linuxbridge-agent
openstack-controller-node01 ~# systemctl restart neutron-dhcp-agent
openstack-controller-node01 ~# systemctl restart neutron-metadata-agent
openstack-controller-node01 ~# systemctl restart neutron-l3-agent
</syntaxhighlight>

各エージェントが、neutron サービスと適切に連携できていることを確認します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack network agent list --agent-type=dhcp
+--------------------------------------+------------+-----------------------------+-------------------+-------+-------+--------------------+
| ID                                   | Agent Type | Host                        | Availability Zone | Alive | State | Binary             |
+--------------------------------------+------------+-----------------------------+-------------------+-------+-------+--------------------+
| 46c78c73-9ef5-4236-9b89-83e261a5f310 | DHCP agent | openstack-controller-node01 | nova              | :-)   | UP    | neutron-dhcp-agent |
+--------------------------------------+------------+-----------------------------+-------------------+-------+-------+--------------------+

openstack-controller-node01 ~# openstack network agent list --agent-type=metadata
+--------------------------------------+----------------+-----------------------------+-------------------+-------+-------+------------------------+
| ID                                   | Agent Type     | Host                        | Availability Zone | Alive | State | Binary                 |
+--------------------------------------+----------------+-----------------------------+-------------------+-------+-------+------------------------+
| 3cff3bf2-d7b3-4102-8e18-843f070da103 | Metadata agent | openstack-controller-node01 | None              | :-)   | UP    | neutron-metadata-agent |
+--------------------------------------+----------------+-----------------------------+-------------------+-------+-------+------------------------+
</syntaxhighlight>

Alive のところに、笑顔<code>:-)</code> が出ていればOKです。

= Compute ノードのNetwork 設定 =

; Install and configure compute node
: https://docs.openstack.org/neutron/wallaby/install/compute-install-ubuntu.html

Compute は、インスタンスにネットワーク接続とセキュリティグループ機能を提供します。
次の設定は、Compute ノード<code>openstack-compute-node01</code>で行います。

== コンポーネントのインストール ==

<syntaxhighlight lang="console">
openstack-compute-node01 ~# apt-get install -y neutron-linuxbridge-agent
</syntaxhighlight>

== 共通コンポーネントの設定 ==
Network の共通コンポーネントの設定は、認証、メッセージキュー、プラグインを含みます。

* /etc/neutron/neutron.conf @ openstack-compute-node01
<syntaxhighlight lang="text">
[DEFAULT]
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

== ネットワークオプション(Self-service)の設定 ==

; Networking Option 2: Self-service networks
: https://docs.openstack.org/neutron/wallaby/install/compute-install-option2-ubuntu.html

Self-service を構築するOpenStack 設定のための、ネットワークオプション設定を行います。

L2 ブリッジエージェントを設定します。

* /etc/neutron/plugins/ml2/linuxbridge_agent.ini @ openstack-compute-node01
<syntaxhighlight lang="console">
[linux_bridge]
physical_interface_mappings = provider:enp1s0

......

[vxlan]
enable_vxlan = true
local_ip = 192.168.2.72  # <- 管理セグメントのIP アドレスを設定します
l2_population = true
......

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
......
</syntaxhighlight>

Linux カーネルが、ネットワークブリッジをサポートしているか調べるために、<code>net.bridge.bridge-nf-call-iptables</code>, <code>net.bridge.bridge-nf-call-ip6tables</code> のパラメータが1 になっていることを確認してください。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# sysctl -a | grep net.bridge.bridge-nf-call-
</syntaxhighlight>

何も表示されない場合は、<code>br_netfilter</code> カーネルモジュールをロードします。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# modprobe br_netfilter
openstack-compute-node01 ~# cat << 'EOF' > /etc/sysctl.d/br_netfilter.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

openstack-compute-node01 ~# sysctl --system
</syntaxhighlight>

== Configure the Compute service to use the Networking service ==

; Configure the Compute service to use the Networking service
: https://docs.openstack.org/neutron/wallaby/install/compute-install-ubuntu.html

<code>/etc/nova/nova.conf</code> ファイルを開いて、以下のように編集します。

* /etc/nova/nova.conf @ openstack-compute-node01
<syntaxhighlight lang="text">
[DEFAULT]
......
# For using Linux bridge(?).
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

== インストールの仕上げ処理 ==
設定が完了したら、サービスを再起動します。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# systemctl restart nova-compute
openstack-compute-node01 ~# systemctl restart neutron-linuxbridge-agent
</syntaxhighlight>

= その他参考 =

; Install Kubernetes Cluster on Ubuntu 20.04 with kubeadm
: https://computingforgeeks.com/deploy-kubernetes-cluster-on-ubuntu-with-kubeadm/

