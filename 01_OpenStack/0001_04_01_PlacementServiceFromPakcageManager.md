= 概要 =
Placement を以下のドメイン、プロジェクトに構築していきます。

* Domain: example
* Project: service

= Installation =

; Placement
: https://docs.openstack.org/placement/latest/

; Installation (Placement)
: https://docs.openstack.org/placement/latest/install/index.html

; Installation - Ubuntu (Placement)
: https://docs.openstack.org/placement/latest/install/install-ubuntu.html

Placement は、Apache 環境下で動く<code>placement-api</code> WSGI スクリプトのためのもので、nginx 等の他のWSGI 可能なWeb サーバでも利用可能です。
インストールしたパッケージ管理システムに依存しますが、たいていは<code>/usr/bin</code>, <code>/usr/local/bin</code> にスクリプトはあります。

<code>placement-api</code> は、一般的なWeb アプリケーションサーバが見つけることのできるロケーションに保存されています。
これが意味することは、多くの異なるサーバで実行することができることを意味します。
例えば、実行可能な環境としては、下記のようなものがあります。

* apache2 とmod wsgi
* apache2 とmode proxy uwsgi
* nginx とuwsgi
* nginx とgunicorn

== Database の同期 ==
<code>placement</code> サービスは、設定ファイル<code>placement_database</code> セクションで定義されているDB を使用します。
<code>placemant-manage</code> は、DB のテーブルを、適切なフォーマットへ変換してくれるツールです。

== アカウントと、サービスカタログの作成 ==
Keystone に<code>placement</code> 管理者ユーザを作成します。

= Ubuntu でのPlacement のインストールと設定 =

; Install and configure Placement for Ubuntu
: https://docs.openstack.org/placement/wallaby/install/install-ubuntu.html

Placement サービスをインストールする前に、Database、認証情報、API エンドポイントを作成する必要があります。

== Database の作成 ==
DB にroot ユーザ権限でログインし、Database とテーブルを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# mysql
......
MariaDB [(none)]> CREATE DATABASE placement;
MariaDB [(none)]> GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'p@ssw0rd';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'p@ssw0rd';
MariaDB [(none)]> quit
</syntaxhighlight>

== ユーザとエンドポイントの設定 ==

管理者の認証情報をロードして、Placement サービスを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# . ./admin-openrc
openstack-controller-node01 ~# openstack user create --domain default --password=p@ssw0rd placement
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | f120ded94594467abe4be838d17bd7ad |
| enabled             | True                             |
| id                  | 4946d2169fe144aa86639065904a83ed |
| name                | placement                        |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
</syntaxhighlight>

Admin ロールで、Placement にユーザを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack role add --project service --user placement admin
</syntaxhighlight>

Placement API エントリをService カタログに作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack service create --name placement --description "Placement API" placement
+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | Placement API                    |
| enabled     | True                             |
| id          | d0e68bb17792425a80e93fe11047334f |
| name        | placement                        |
| type        | placement                        |
+-------------+----------------------------------+
</syntaxhighlight>

Placement API サービスエンドポイントを作成します。<br />
// 以下のコマンドのポート番号は、場合によっては8780 の可能性もあります。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack endpoint create --region RegionOne placement public http://openstack-controller-node01:8778
+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 2fbdec0285084e39bddf29ffcbdb0d5f |
| interface    | public                           |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | d0e68bb17792425a80e93fe11047334f |
| service_name | placement                        |
| service_type | placement                        |
| url          | http://controller:8778           |
+--------------+----------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne placement internal http://openstack-controller-node01:8778
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | 19615620bfdc49dd906a45c045684b31        |
| interface    | internal                                |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | d0e68bb17792425a80e93fe11047334f        |
| service_name | placement                               |
| service_type | placement                               |
| url          | http://openstack-controller-node01:8778 |
+--------------+-----------------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne placement admin http://openstack-controller-node01:8778
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | 466327eceb6945bea9fca3f1ae0706b6        |
| interface    | admin                                   |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | d0e68bb17792425a80e93fe11047334f        |
| service_name | placement                               |
| service_type | placement                               |
| url          | http://openstack-controller-node01:8778 |
+--------------+-----------------------------------------+
</syntaxhighlight>

== コンポーネントの設定とインストール ==

<code>placement-api</code> をインストールしていきます。
<code>placement-api</code> をインストールすると、デフォルトの設定ファイルもインストールされますが、必要に応じて編集する必要があります。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y placement-api
</syntaxhighlight>

<code>/etc/placement/placement.conf</code> ファイルを編集して、以下のアクションを指定します。

* /etc/placement/placement.conf @ openstack-controller-node01
<syntaxhighlight lang="console">
[placement_database]
# ...
connection = mysql+pymysql://placement:p@ssw0rd@openstack-controller-node01/placement
......

[api]
......
auth_strategy = keystone
......

[keystone_authtoken]
......
#www_authenticate_uri = http://openstack-controller-node01:5000/
auth_url = http://openstack-controller-node01:5000/v3
memcached_servers = openstack-controller-node01:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = p@ssw0rd
......
</syntaxhighlight>

<code>placement</code> DB を作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "placement-manage db sync" placement
/usr/lib/python3/dist-packages/pymysql/cursors.py:170: Warning: (1280, "Name 'alembic_version_pkc' ignored for PRIMARY key.")
  result = self._query(query)

// 上記のように警告が出たが、一旦は無視する
</syntaxhighlight>

一通りの設定が完了したら、Apache をリスタートさせます。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl restart apache2
</syntaxhighlight>

= インストールの検証 =

; Verify Installation
: https://docs.openstack.org/placement/wallaby/install/verify.html

Placement サービスの検証を行います。
コマンドラインから、管理者権限の認証情報をロードします。

<syntaxhighlight lang="console">
@openstack-controller-node01 ~# . ./admin-openrc
</syntaxhighlight>

設定が想定通りになっているか確認します。

<syntaxhighlight lang="console">
@openstack-controller-node01 ~# placement-status upgrade check
+----------------------------------+
| Upgrade Check Results            |
+----------------------------------+
| Check: Missing Root Provider IDs |
| Result: Success                  |
| Details: None                    |
+----------------------------------+
| Check: Incomplete Consumers      |
| Result: Success                  |
| Details: None                    |
+----------------------------------+
// 出力内容は、Placement のバージョンによって異なります
</syntaxhighlight>

== Placement API へコマンドの実行 ==
Placement API へコマンドを実行していきます。
まず、<code>osc-placement</code> プラグインをインストールします。<br /><br />

Python のパッケージマネージャとして、ディストリビューションで用意されたものを使用する場合、Python3 に対応するために、<code>pip3</code> を使用するもしくは<code>python3-osc-placement</code> をインストールするように指定するなど、適切な対応をするようにしてください。

<syntaxhighlight lang="console">
@openstack-controller-node01 ~# apt-get install python3-osc-placement
</syntaxhighlight>

利用可能なクラス、特性リソースとその情報を確認します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack --os-placement-api-version 1.2 resource class list --sort-column name
+----------------------------+
| name                       |
+----------------------------+
| DISK_GB                    |
| FPGA                       |
| IPV4_ADDRESS               |
| ......                     |
| VGPU                       |
| VGPU_DISPLAY_HEAD          |
+----------------------------+

openstack-controller-node01 ~# openstack --os-placement-api-version 1.6 trait list --sort-column name
+---------------------------------------+
| name                                  |
+---------------------------------------+
| COMPUTE_ACCELERATORS                  |
| COMPUTE_DEVICE_TAGGING                |
| COMPUTE_GRAPHICS_MODEL_CIRRUS         |
| ......                                |
| STORAGE_DISK_HDD                      |
| STORAGE_DISK_SSD                      |
+---------------------------------------+
</syntaxhighlight>

= Placement のアップグレードに関して =

; Upgrade Notes, Upgrading from nova to Placement
: https://docs.openstack.org/placement/wallaby/admin/index.html

説明は割愛。

