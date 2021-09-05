= 概要 =
Compute サービスを以下のドメイン、プロジェクトに構築していきます。

* Domain: example
* Project: service

Placement サービスが既にインストールされていることを、想定しています。

= Compute service =

; Compute service
: https://docs.openstack.org/nova/wallaby/install/

ここでのアーキテクチャは検証用の小さい構成で、商用環境を想定したものではありません。
商用環境を想定したアーキテクチャは、以下のページを参考に考えてみると良いでしょう。

; OpenStack Architecture Design Guide
: https://docs.openstack.org/arch-design/

; OpenStack Operations Guide
: https://docs.openstack.org/operations-guide/

; OpenStack Networking Guide
: https://docs.openstack.org/ocata/networking-guide/

ここでは、商用環境のインストールと比較して、以下の点で違いがあります。

* 複数のネットワークに存在するノードを1 つにまとめている
* サービスネットワークと管理ネットワークが一緒になっている

== ハードウェア要件 ==

[[Image:OpenStack_InstallComputeService_0001.png]]

== ネットワーク ==
ネットワークは<code>Provider Networks</code> と、<code>Self-Service Networks</code> の2 つがあります。
<code>Provider Networks</code> は、最小限のネットワーク要件でシンプルです。
が、以下の構成が欠けています。

* セルフサービス(private)ネットワーク
* レイヤ3 サービス
* Load-Balancer-as-a-Service(LBaaS)
* FireWall-as-a-Service(FWaaS)

これらの機能を使用したい場合は、<code>Self-Service Networks</code> を選んでください。<br /><br />

今回は、<code>Self-Service Networks</code> を使用します。<br />

[[Image:OpenStack_InstallComputeService_0002.png]]<br />

= Compute サービス概要 =
Compute サービスは、OpenStack のInfrastructure-as-a-Service(IaaS) の中心となるものです。
Compute は、クラウドコンピューティングシステムをホストして管理するために使用されます。<br /><br />

Compute は、認証のために<code>Identity</code>、リソースのインベントリの追跡と選択のために<code>Placement</code>、ユーザと管理者のためのGUI である<code>Dashboard</code>といったサービスとコミュニケーションを取ります。
イメージアクセスは、例えば1 プロジェクトで登録できるインスタンス数などで、プロジェクトごとに制限がかけられます。
Compute は、普通のハードウェア上で水平展開でき、インスタンス起動のために、イメージをダウンロードすることもできます。<br /><br />

Compute は、以下の領域でコンポーネントが存在します。

; nova-api service
: ユーザからのAPI 呼び出しを受け取り、応答します。インスタンスを起動するなどの、オーケストレーション機能も提供します

; nova-api-metadata service
: インスタンスからのメタデータアクセスを受け取ります。詳細は<code>https://docs.openstack.org/nova/wallaby/admin/metadata-service.html</code> にあります。

; nova-compute service
: ハイパーバイザAPI を通じて、VM の起動・停止を行うデーモンです。内部では、ユーザからのリクエストを受け取り、KVM やVMWare といった内部コマンドを実行しています。

; nova-scheduler service
: キューからリクエストを受け取り、どのホスト上で仮想マシンを走らせるかを決定します。

; nova-conductor module
: <code>nova-compute</code> サービスとDB の中間に位置するモジュールです。これは<code>nova-compute</code> サービスによる直接的なアクセスを防ぎます。そして<code>nova-conductor</code> モジュールは水平展開することができます。が、このモジュールは<code>nova-compute</code> サービスがデプロイされたノードには、デプロイしないようにしてください。詳細は"Configuration Options"<code>https://docs.openstack.org/nova/wallaby/configuration/config.html</code> を参照してください

; nova-novncproxy daemon
: 起動しているインスタンスへのVNC プロキシを提供します。VNC クライアントをサポートしていないブラウザもサポートします

; nova-spicehtml5proxy daemon
: SPICE 接続を通した、起動中インスタンスへのアクセスを提供します。HTML5 対応のWeb ブラウザクライアントをサポートします

; Queue
: デーモン間で、メッセージを中継します。標準ではRabbitMQ で実現されますが、その他のメッセージキューイングサービスもサポートします

; SQL Database
: クラウド基盤のビルド時及び実行時の状態を管理します。含まれるものとしては、以下のものがあります。
* 利用可能なインスタンスタイプ
* 使用中のインスタンス
* 利用可能なネットワーク
* プロジェクト
DB としては、SQL をサポートしているものであれば、基本大丈夫です。具体的には、(テストや検証目的で)SQLite3、MySQL、MariaDB、PostgreSQL 等です。

= コントローラノードのインストールと設定 =

; Install and configure controller node
: https://docs.openstack.org/nova/wallaby/install/controller-install.html

Compute をインストールする前に、DB、サービスパスワード、API エンドポイントを作成します。

== 事前設定 ==

<syntaxhighlight lang="console">
openstack-controller-node01 ~# mysql
MariaDB [(none)]> CREATE DATABASE nova_api;
MariaDB [(none)]> CREATE DATABASE nova;
MariaDB [(none)]> CREATE DATABASE nova_cell0;
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'p@ssw0rd';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'p@ssw0rd';

MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'p@ssword';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'p@ssw0rd';

MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'p@ssw0rd';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'p@ssw0rd';

MariaDB [(none)]> quit
</syntaxhighlight>

Compute サービスの認証情報を作成、ユーザに管理者ロールの追加を行います。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# . ./admin-openrc

openstack-controller-node01 ~# openstack user create --domain default --password=p@ssw0rd nova
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | f120ded94594467abe4be838d17bd7ad |
| enabled             | True                             |
| id                  | 5b6bc7c059b04a099775da571044511d |
| name                | nova                             |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+

openstack-controller-node01 ~# openstack role add --project service --user nova admin
</syntaxhighlight>

nova サービスエンティティを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack service create --name nova --description "OpenStack Compute" compute
+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | OpenStack Compute                |
| enabled     | True                             |
| id          | 99bcb7320ee74033b822d199f544d6e4 |
| name        | nova                             |
| type        | compute                          |
+-------------+----------------------------------+
</syntaxhighlight>

Compute サービスエンドポイントを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack endpoint create --region RegionOne compute public http://openstack-controller-node01:8774/v2.1
+--------------+----------------------------------------------+
| Field        | Value                                        |
+--------------+----------------------------------------------+
| enabled      | True                                         |
| id           | 3c3fa9dbcbdd48ea8727ae02c0b1408e             |
| interface    | public                                       |
| region       | RegionOne                                    |
| region_id    | RegionOne                                    |
| service_id   | 99bcb7320ee74033b822d199f544d6e4             |
| service_name | nova                                         |
| service_type | compute                                      |
| url          | http://openstack-controller-node01:8774/v2.1 |
+--------------+----------------------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne compute internal http://openstack-controller-node01:8774/v2.1
+--------------+----------------------------------------------+
| Field        | Value                                        |
+--------------+----------------------------------------------+
| enabled      | True                                         |
| id           | f1c40a5302a34808b506eed59e1a878f             |
| interface    | internal                                     |
| region       | RegionOne                                    |
| region_id    | RegionOne                                    |
| service_id   | 99bcb7320ee74033b822d199f544d6e4             |
| service_name | nova                                         |
| service_type | compute                                      |
| url          | http://openstack-controller-node01:8774/v2.1 |
+--------------+----------------------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne compute admin http://openstack-controller-node01:8774/v2.1
+--------------+----------------------------------------------+
| Field        | Value                                        |
+--------------+----------------------------------------------+
| enabled      | True                                         |
| id           | f705d7ea76a34808a40c732e1e022c38             |
| interface    | admin                                        |
| region       | RegionOne                                    |
| region_id    | RegionOne                                    |
| service_id   | 99bcb7320ee74033b822d199f544d6e4             |
| service_name | nova                                         |
| service_type | compute                                      |
| url          | http://openstack-controller-node01:8774/v2.1 |
+--------------+----------------------------------------------+
</syntaxhighlight>

== コンポーネントのインストールと設定 ==

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y nova-api nova-conductor nova-novncproxy nova-scheduler
</syntaxhighlight>

DB、メッセージキューサービス、Keystone、vnc に関する接続情報を設定します。

* /etc/nova/nova.conf @ openstack-controller-node01
<syntaxhighlight lang="console">
[DEFAULT]
# ...
#lock_path = /var/lib/nova/tmp    # (バグのためlog_dir はコメントアウトする??)
transport_url = rabbit://openstack:p@ssw0rd@openstack-controller-node01:5672/
my_ip = 192.168.2.71
# ...

[api_database]
# ...
connection = mysql+pymysql://nova:p@ssw0rd@openstack-controller-node01/nova_api
# ...

[database]
# ...
connection = mysql+pymysql://nova:p@ssw0rd@openstack-controller-node01/nova
# ...

[api]
# ...
auth_strategy = keystone
# ...

[keystone_authtoken]
# ...
www_authenticate_uri = http://openstack-controller-node01:5000/
auth_url = http://openstack-controller-node01:5000/
memcached_servers = openstack-controller-node01:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = p@ssw0rd
# ...

[vnc]
enabled = true
server_listen = $my_ip
server_proxyclient_address = $my_ip
# ...

[glance]
# ...
api_servers = http://openstack-controller-node01:9292    # (イメージサービスの場所を指定します)
# ...

[oslo_concurrency]
# ...
lock_path = /var/lib/nova/tmp
# ...

[placement]
# ...
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://openstack-controller-node01:5000/v3
username = placement
password = p@ssw0rd
</syntaxhighlight>

設定ファイルを編集したら、<code>nova-api</code> データベースを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "nova-manage api_db sync" nova
</syntaxhighlight>

<code>cell0</code> データベースを登録します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
</syntaxhighlight>

<code>cell1</code> セルを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
</syntaxhighlight>

<code>nova</code> データベースを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "nova-manage db sync" nova
</syntaxhighlight>

<code>cell0</code> と<code>cell1</code> が正しく登録されたことを確認します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
+-------+--------------------------------------+-----------------------------------------------------------+------------------------------------------------------------------+----------+
|  Name |                 UUID                 |                       Transport URL                       |                       Database Connection                        | Disabled |
+-------+--------------------------------------+-----------------------------------------------------------+------------------------------------------------------------------+----------+
| cell0 | 00000000-0000-0000-0000-000000000000 |                           none:/                          | mysql+pymysql://nova:****@openstack-controller-node01/nova_cell0 |  False   |
| cell1 | 89df27af-d35f-4248-b15c-eea9fc91fba4 | rabbit://openstack:****@openstack-controller-node01:5672/ |    mysql+pymysql://nova:****@openstack-controller-node01/nova    |  False   |
+-------+--------------------------------------+-----------------------------------------------------------+------------------------------------------------------------------+----------+
</syntaxhighlight>

確認できたら、各サービスを再起動します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl restart nova-api
openstack-controller-node01 ~# systemctl restart nova-scheduler
openstack-controller-node01 ~# systemctl restart nova-conductor
openstack-controller-node01 ~# systemctl restart nova-novncproxy
</syntaxhighlight>

