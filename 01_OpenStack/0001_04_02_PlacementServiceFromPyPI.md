= 概要 =
Placement をPiPy を使ってインストールしていきます。

= Installation =

; Install and configure Placement from PyPI
: https://docs.openstack.org/placement/wallaby/install/from-pypi.html

# = 必要パッケージのインストール =
# `python-openstackclient` がインストールされていない場合、それをインストールします。
# 
# <syntaxhighlight lang="console">
# openstack-controller-node01 # ## pip install python-openstackclient
# </syntaxhighlight>

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

== ユーザとエンドポイントの作成 ==
管理者の認証情報をロードして、Placement サービスを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# . ./admin-openrc
openstack-controller-node01 ~# openstack user create --domain default --password=p@ssw0rd placement
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | 1cda3b145bc64dbebabef5b5a26ef725 |
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
| id          | 1efd6f5ac12b4df0a1fda3bdec5261ca |
| name        | placement                        |
| type        | placement                        |
+-------------+----------------------------------+
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack endpoint create --region RegionOne placement public http://openstack-controller-node01:8778
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | 9ac96baab49f496d97203bc036c9c998        |
| interface    | public                                  |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | 1efd6f5ac12b4df0a1fda3bdec5261ca        |
| service_name | placement                               |
| service_type | placement                               |
| url          | http://openstack-controller-node01:8778 |
+--------------+-----------------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne placement internal http://openstack-controller-node01:8778
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | 985c0d1f42754ebdb3c4f203070de36a        |
| interface    | internal                                |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | 1efd6f5ac12b4df0a1fda3bdec5261ca        |
| service_name | placement                               |
| service_type | placement                               |
| url          | http://openstack-controller-node01:8778 |
+--------------+-----------------------------------------+

openstack-controller-node01 ~# openstack endpoint create --region RegionOne placement admin http://openstack-controller-node01:8778
+--------------+-----------------------------------------+
| Field        | Value                                   |
+--------------+-----------------------------------------+
| enabled      | True                                    |
| id           | c3e716fd58404651bf046fe266614e66        |
| interface    | admin                                   |
| region       | RegionOne                               |
| region_id    | RegionOne                               |
| service_id   | 1efd6f5ac12b4df0a1fda3bdec5261ca        |
| service_name | placement                               |
| service_type | placement                               |
| url          | http://openstack-controller-node01:8778 |
+--------------+-----------------------------------------+
</syntaxhighlight>

== placement ユーザの作成 ==
<syntaxhighlight lang="console">
openstack-controller-node01 # groupadd placement
openstack-controller-node01 # useradd -c "User for Placement API" -g placement -s /bin/false -m placement
</syntaxhighlight>

== openstack-placement のインストール ==

<syntaxhighlight lang="console">
openstack-controller-node01 ~# pip install openstack-placement pymysql
</syntaxhighlight>

次に、Placement の設定ファイルを作成します。
Placement の設定ファイルはデフォルトで`/etc/placement/placement.conf` になります。
ファイルがない場合は、新規作成してください。

もし、設定ファイルのロケーションを変更したい場合は、`OS_PLACEMENT_CONFIG_DIR` 環境変数を設定して変更します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# mkdir -p /etc/placement
openstack-controller-node01 ~# vim /etc/placement/placement.conf
</syntaxhighlight>

* /etc/placement/placement.conf @ openstack-controller-node01
<syntaxhighlight lang="text">
[placement_database]
connection = mysql+pymysql://placement:p@ssw0rd@openstack-controller-node01/placement

[api]
auth_strategy = keystone

[keystone_authtoken]
www_authenticate_uri = http://openstack-controller-node01:5000/
auth_url = http://openstack-controller-node01:5000/
memcached_servers = openstack-controller-node01:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = p@ssw0rd
</syntaxhighlight>

<syntaxhighlight lang="text">
openstack-controller-node01 ~# chown root:placement /etc/placement/placement.conf
openstack-controller-node01 ~# chmod 640 /etc/placement/placement.conf
</syntaxhighlight>

== placement DB の作成 ==
下記コマンドを使って、DBを同期します。
公式ドキュメントでは、placement ユーザの指定がありませんでしたが、ここでは念の為指定しておくようにします。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "placement-manage db sync" placement
</syntaxhighlight>

<code>uwsgi</code> コマンドを使って、placement-api のテストサーバーを起動します。
<code>--wsgi-file</code> オプションで指定するplacement-api コマンドのパスですが、公式ドキュメントでは<code>/usr/bin/placement-api</code> となっていましたが、私の環境では<code>/usr/bin/placement-api</code> となっていたので、そちらを使うようにします。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# pip install uwsgi
openstack-controller-node01 ~# uwsgi -M --http :8778 --wsgi-file /usr/local/bin/placement-api --processes 2 --threads 10
</syntaxhighlight>

Placement が起動したら、curl コマンドで動作確認をしてみましょう。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# curl http://openstack-controller-node01:8778/
</syntaxhighlight>

動作確認が完了したら、`Ctrl + C` を押下してuwsgi コマンドを終了します。

== Apache モジュールの設定 ==

次にApache の設定ファイルを作成します(package マネージャに入っているものを参考に作成)。

* /etc/apache2/sites-available/placement-api.conf @ openstack-controller-node01
<syntaxhighlight lang="text">
Listen 8778

<VirtualHost *:8778>
    WSGIScriptAlias / /usr/local/bin/placement-api
    WSGIDaemonProcess placement-api processes=5 threads=1 user=placement group=placement display-name=%{GROUP}
    WSGIProcessGroup placement-api
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    LimitRequestBody 114688

    ErrorLog /var/log/apache2/placement_api_error.log
    CustomLog /var/log/apache2/placement_api_access.log combined

    <Directory /usr/local/bin>
        Require all granted
    </Directory>
</VirtualHost>

Alias /placement /usr/local/bin/placement-api
<Location /placement>
    SetHandler wsgi-script
    Options +ExecCGI

    WSGIProcessGroup placement-api
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
</Location>
</syntaxhighlight>

設定ファイルを作成したら、それを有効化して、Apache をリロードします。

<syntaxhighlight lang="console">
openstack-controller-node01 # a2ensite placement-api
openstack-controller-node01 # systemctl reload apache2
</syntaxhighlight>

= 参考 =
; httpd unable to execute `/usr/bin/placement-api`
: https://storyboard.openstack.org/#!/story/2006905

