= Keystone =

; Keystone Installation Tutorial
: https://docs.openstack.org/keystone/wallaby/install/

OpenStack Identity サービスであるKeystone をコントローラノードにインストールします。
スケーラビリティのため、Fernet トークンのデプロイと、リクエストの処理のためにHTTP サーバをインストールします。

== Identity サービスの概要 ==
Identity サービスは、認証、認可、サービスのカタログを管理するためのものです。
これは、ユーザがまず始めにアクセスするサービスで、認証と認可を受け、トークンを使ってその他のOpenStack サービスが利用できる流れになっています。
また、LDAP のような外部のユーザ管理システムと連携することもできるようになっています。<br /><br />

Identity サービスによって管理されているCatalog によって、ユーザと機能は他のサービスに位置することができます。
Catalog とは、その名前から推測できるとおり、利用可能なサービスの一覧が記録されたものになります。<br />
それぞれのサービスは、1 つ以上のエンドポイントを持つことができ、<code>admin</code>, <code>internal</code>, <code>public</code> といったステータスを持つことができます。
商用環境では、セキュリティの観点から異なるタイプを持つエンドポイントが、異なるネットワークごとに公開することもできます。

例えば、一般の利用者に彼らのクラウドを管理できるようにするために、インターネットセグメントに<code>public</code> なAPI エンドポイントを置くことができます。
<code>admin</code> なAPI エンドポイントは、クラウドインフラ管理者向けに閉じたネットワークセグメントに置くことができます。
<code>internal</code> API ネットワークはOpenStack サービスを含んでいるホストへ制限することができます。<br /><br />

OpenStack はスケーラビリティのため、複数のリージョンをサポートしています。
シンプルにするために、今回はすべてのエンドポイントタイプは管理ネットワークセグメントに置くことにし、<code>RegionOne</code> リージョンのみデプロイしていきます。<br /><br />

ロージョン、サービス、エンドポイントが、Identity サービス内にサービスCatalog が作成されます。
これらは、Identity サービスがインストールされたあとに実行することが可能です。<br /><br />

Identity サービスは次のコンポーネントから構成されます。

; Server
: REST な認証・認可サービスを提供する中央サーバ

; Drivers
: ドライバ、またはバックエンド。中央サーバに統合されています。OpenStack の外部にあるユーザ情報リポジトリ(例えばLDAP やSQL DB)にアクセスするのに利用されます

; Modules
: Identity サービスで利用されているOpenStack コンポーネントのアドレススペースで実行されるミドルウェアモジュール。サービスリクエストに介入し、ユーザの認証情報を展開し、認可のために中央サーバへ送ります。OpenStack コンポーネントと、ミドルウェアを統合するためにPython Web Server Gateway Interface を使っています。

== インストールと設定 ==

まず、DB の作成とアカウントの設定を行います。
<code>GRANT</code> クエリは<code>0 rows affected</code> が出力されますが、問題なく反映されています。
反映されているかを確認するには、<code>SHOW GRANTS FOR 'keystone'@'localhost';</code> クエリを実行します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# mysql
......
MariaDB [(none)]> CREATE DATABASE keystone;
Query OK, 1 row affected (0.001 sec)
......
MariaDB [(none)]> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'p@ssw0rd';
Query OK, 0 rows affected (0.003 sec)
......
MariaDB [(none)]> GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'p@ssw0rd';
Query OK, 0 rows affected (0.001 sec)
......
MariaDB [(none)]> SHOW GRANTS FOR 'keystone'@'localhost';
+-----------------------------------------------------------------------------------------------------------------+
| Grants for keystone@localhost                                                                                   |
+-----------------------------------------------------------------------------------------------------------------+
| GRANT USAGE ON *.* TO `keystone`@`localhost` IDENTIFIED BY PASSWORD '*****************************************' |
| GRANT ALL PRIVILEGES ON `keystone`.* TO `keystone`@`localhost`                                                  |
+-----------------------------------------------------------------------------------------------------------------+
......
MariaDB [(none)]> quit
</syntaxhighlight>

keystone, 関連のパッケージをインストールします。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y keystone
</syntaxhighlight>

<code>/etc/keystone/keystone.conf</code> ファイルを編集します。<br />
// connection のパスワードに"@" が含まれていても、特にURL エンコードしなくても大丈夫なようです

* /etc/keystone/keystone.conf
<syntaxhighlight lang="console">
[database]
......
connection = mysql+pymysql://keystone:p@ssw0rd@openstack-controller-node01/keystone
......
[token]
......
provider = fernet
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "keystone-manage db_sync" keystone
  -> ログは"/var/log/keystone/keystone-manage.log" に出力されます
</syntaxhighlight>

DBが作成されたかを確認してみましょう。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# mysql -u keystone --password=p@ssw0rd -h openstack-controller-node01 keystone -e 'SHOW TABLES'
</syntaxhighlight>

Fernet key リポジトリを初期化します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
openstack-controller-node01 ~# keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 ~# keystone-manage bootstrap --bootstrap-password 'p@ssw0rd' \
                                   --bootstrap-admin-url http://openstack-controller-node01:5000/v3/ \
                                   --bootstrap-internal-url http://openstack-controller-node01:5000/v3/ \
                                   --bootstrap-public-url http://openstack-controller-node01:5000/v3/ \
                                   --bootstrap-region-id RegionOne
</syntaxhighlight>

== Apache HTTP サーバ ==

ServerName をApache の設定ファイルに追加します。
Ubuntu 20.04 の場合は"/etc/apache2/sites-enabled/000-default.conf" に設定すると良いでしょう。
また、必要に応じてSSL の設定を追加してください。

* /etc/apache2/sites-enabled/000-default.conf
<syntaxhighlight lang="text">
ServerName openstack-controller-node01
</syntaxhighlight>

Apache サーバを再起動します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# systemctl restart apache2
</syntaxhighlight>

環境変数を設定し、openstack コマンドで管理者ユーザにてアクセスできるようにします。

<syntaxhighlight lang="console">
export OS_USERNAME=admin
export OS_PASSWORD=p@ssw0rd
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://openstack-controller-node01:5000/v3
export OS_IDENTITY_API_VERSION=3
</syntaxhighlight>

これらの環境変数は、<code>keystone-manage</code> bootstrap で作成されるものになります。

== Domain, Projects, Users, Roles の作成 ==

Identity サービスは、OpenStack の各サービスに認証サービスを提供します。
認証サービスは、Domain, Projects, Users, Roles の組み合わせを使います。<br /><br />

デフォルトDomain はkeystone-manage bootstrap の段階で既に作成されています。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack domain list
+---------+---------+---------+--------------------+
| ID      | Name    | Enabled | Description        |
+---------+---------+---------+--------------------+
| default | Default | True    | The default domain |
+---------+---------+---------+--------------------+
</syntaxhighlight>

Domain の作成を体験するために、これとは別に'''example''' ドメインを作成していきます。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack domain create --description "An Example Domain" example
+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | An Example Domain                |
| enabled     | True                             |
| id          | f5f7187a9500488da040041ad0a46cbf |
| name        | example                          |
| options     | {}                               |
| tags        | []                               |
+-------------+----------------------------------+

openstack-controller-node01 ~# openstack domain list
+----------------------------------+---------+---------+--------------------+
| ID                               | Name    | Enabled | Description        |
+----------------------------------+---------+---------+--------------------+
| default                          | Default | True    | The default domain |
| f5f7187a9500488da040041ad0a46cbf | example | True    | An Example Domain  |
+----------------------------------+---------+---------+--------------------+
</syntaxhighlight>

次にService を作成します。
通常(非管理者)のタスクは、unprivileged なプロジェクトを使うべきです。
そのために、この例では<code>service</code> プロジェクトと<code>myuser</code> ユーザを作成していきます。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack project create --domain default --description "Service Project" service
+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | Service Project                  |
| domain_id   | f5f7187a9500488da040041ad0a46cbf |
| enabled     | True                             |
| id          | bee66d9f8c024d24bedacb9b368e1da0 |
| is_domain   | False                            |
| name        | service                          |
| options     | {}                               |
| parent_id   | f5f7187a9500488da040041ad0a46cbf |
| tags        | []                               |
+-------------+----------------------------------+

openstack-controller-node01 ~# openstack project create --domain default --description "Demo Project" myproject
......

openstack-controller-node01 ~# openstack project list --long --domain default
+----------------------------------+-----------+-----------+-----------------------------------------------+---------+
| ID                               | Name      | Domain ID | Description                                   | Enabled |
+----------------------------------+-----------+-----------+-----------------------------------------------+---------+
| dde313663a2c4c0d98dacd00a8beeb28 | admin     | default   | Bootstrap project for initializing the cloud. | True    |
| d57aa32386f945d4b74e8454dc7bd60e | myproject | default   | Demo Project                                  | True    |
| 55c77664241f4ccdb930da37f54850c5 | service   | default   | Service Project                               | True    |
+----------------------------------+-----------+-----------+-----------------------------------------------+---------+

openstack-controller-node01 ~# openstack user create --domain default --password=p@ssw0rd myuser
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | f5f7187a9500488da040041ad0a46cbf |
| enabled             | True                             |
| id                  | 5c9632d6ada44ad4a2f26409f73e55bf |
| name                | myuser                           |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+

@openstack-controller-node01 ~# openstack user list --domain default --long
+----------------------------------+--------+---------+---------+-------------+-------+---------+
| ID                               | Name   | Project | Domain  | Description | Email | Enabled |
+----------------------------------+--------+---------+---------+-------------+-------+---------+
| d78d035d1331485b8000ce75c3de0925 | admin  |         | default |             |       | True    |
| 413f3f0c577f4797bd4179351c124431 | myuser |         | default |             |       | True    |
+----------------------------------+--------+---------+---------+-------------+-------+---------+
</syntaxhighlight>

次に<code>myrole</code> を作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack role create myrole
+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | None                             |
| domain_id   | None                             |
| id          | 842a2cc370c944858a4b8bcd8ca04e3d |
| name        | myrole                           |
| options     | {}                               |
+-------------+----------------------------------+
</syntaxhighlight>

<code>service</code> プロジェクトと<code>myuser</code> ユーザに<code>myrole</code> ロールを追加します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack role add --project myproject --user myuser myrole
</syntaxhighlight>

ロールの割当を行ったら、次のコマンドで、各プロジェクトに割り当てられたロールを確認します。

```
openstack-controller-node01 ~# openstack role assignment list --name
......
```


以上でDomain, Project, User, Role の作成は完了です。
複数のDomain やProject を作成する場合は、この手順を繰り返してください。

== 検証 ==

; Verify operation
: https://docs.openstack.org/keystone/wallaby/install/keystone-verify-ubuntu.html

Identity サービスの設定を検証していきます。<br /><br />

一旦、<code>OS_AUTH_URL</code>, <code>OS_PASSWORD</code> 環境変数を削除します。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# unset OS_AUTH_URL OS_PASSWORD
</syntaxhighlight>

管理者として、認証トークンをリクエストしてみます。

* admin ユーザ
<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack --os-auth-url http://openstack-controller-node01:5000/v3 \
                                   --os-project-domain-name Default --os-user-domain-name Default \
                                   --os-project-name admin --os-username admin token issue
Password:
+------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field      | Value                                                                                                                                                                                   |
+------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| expires    | 2021-04-10T16:41:56+0000                                                                                                                                                                |
| id         | gAAAAABgccdERqSz8infQwRWzeRGQtsDwJMVXW0V6-os-7Xp5uv5YtKn_YskQjQnQ4kqmo4d5W0tLEYAtNNnfMG_DEFaOVPbxrte8X6u8i4yX_eVKeC-NAqdVoE3PmPknIbnTo105yrBTD8Iytw6MYt2w7dzdETEqpS65XTEVzTCHld0vLVo9sA |
| project_id | 2e694f02857540fe9aa141192f078bc1                                                                                                                                                        |
| user_id    | 302f002bf6394e15ae288e4ca10ba585                                                                                                                                                        |
+------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
</syntaxhighlight>

また、独自に作成したサービスの<code>myuser</code> ユーザの認証トークンをリクエストしてみます。

* admin ユーザ
<syntaxhighlight lang="console">
openstack-controller-node01 ~# openstack --os-auth-url http://openstack-controller-node01:5000/v3 \
                                   --os-project-domain-name Default --os-user-domain-name Default \
                                   --os-project-name myproject --os-username myuser token issue
Password:
+------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field      | Value                                                                                                                                                                                   |
+------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| expires    | 2021-04-10T16:43:14+0000                                                                                                                                                                |
| id         | gAAAAABgcceSqSvu886USYaWKQ5JcxGylL-wQTTfAgYaDrmx9WkOHfOuqTt5cH7cd0D7Jis7JDp9fzQmwrw40laeByBefqcdn7EaIDrqXvkapY6zsZWjlJmRw6HPk3aEB-eB3GJNmvQa46dGvspqTq5-Bgy6jbaqDn4JmtUwjyYNEkE2t_WseVI |
| project_id | bee66d9f8c024d24bedacb9b368e1da0                                                                                                                                                        |
| user_id    | 5c9632d6ada44ad4a2f26409f73e55bf                                                                                                                                                        |
+------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
</syntaxhighlight>

== OpenStack クライアント環境スクリプトの作成 ==

; Create OpenStack client environment scripts
: https://docs.openstack.org/keystone/wallaby/install/keystone-openrc-ubuntu.html

クライアント環境をセットアップするための、OpenRC ファイルを作成します。
前に、環境変数を設定してクライアントの認証情報を設定していましたが、それと同等の処理をするスクリプトを作成します。<br /><br />

今回は<code>admin</code> 用と、<code>service</code> プロジェクト用の2 つのクライアント環境をセットアップするOpenRC ファイルを作成します。
ファイルの保管場所は、厳密に決まりはありませんが、認証情報などの重要な情報が記載されているファイルなので、安全な場所に保管するようにしてください。

* ~/admin-openrc
<syntaxhighlight lang="shell">
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=p@ssw0rd
export OS_AUTH_URL=http://openstack-controller-node01:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
</syntaxhighlight>

* ~/demo-openrc
<syntaxhighlight lang="shell">
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=myproject
export OS_USERNAME=myuser
export OS_PASSWORD=p@ssw0rd
export OS_AUTH_URL=http://openstack-controller-node01:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
</syntaxhighlight>

OpenRC ファイルを作成したら、それをロードし、コマンドを実行してみてください。

* admin-openrc
<syntaxhighlight lang="console">
openstack-controller-node01 ~# . ./admin-openrc

openstack-controller-node01 ~# openstack token issue
+------------+--------------------------------------------------+
| Field      | Value                                            |
+------------+--------------------------------------------------+
| expires    | 2021-04-11T04:59:06+0000                         |
| id         | gAAAAABgcnQKvRF0xlhYRcYWu9bImgrjrQT-LzA0ZW...    |
| project_id | 2e694f02857540fe9aa141192f078bc1                 |
| user_id    | 302f002bf6394e15ae288e4ca10ba585                 |
+------------+--------------------------------------------------+
</syntaxhighlight>

= Keystone アーキテクチャ =

; Keystone Architecture
: https://docs.openstack.org/keystone/wallaby/getting-started/architecture.html

== Services ==

Keystone は1 つ以上のエンドポイントで公開されている内部サービスのグループとして、構成されています。
これらの内部サービスは、フロントエンドからは、結合されたものとして利用することができるようになっています。
例えば、フロントエンドに対する認証リクエストは、ユーザ、プロジェクトとパスワード等が検証されて、結果がOK ならばToken サービスを使ってフロントへ返す仕組みになっています。

== Identity ==

Identity サービスは認証情報を検証し、ユーザとグループに関するデータを提供します。
このデータは、Identity サービスによって管理され、データに対してCRUD 操作ができるようになっています(ユーザの登録、変更、削除など)。
また、Identity サービスはLDAP やDB などをバックエンドに持つことができ、データのリポジトリとしてそれらを指定することもできます。

=== Users ===
ユーザは、個々のAPI 利用者として表現されます。
ユーザは特定のドメインに属している必要があり、ドメイン内でユニークである必要があります(ドメインをまたいで、重複するのはOK)。

=== Groups ===
グループは、ユーザの集合として表現されます。
グループは特定のドメインに属している必要があり、ドメイン内でユニークである必要があります。

== Resource ==
Resource サービスは、Project とDomain に関するデータを提供します。

=== Projects ===
Project は、所有者の基本単位となります。
すべてのOpenStack 内のリソースは、特定のプロジェクトに属している必要があります。
また、Project は特定のドメインに属している必要があり、ドメイン内でユニークである必要があります。
ドメインが指定されなかった場合、そのプロジェクトはdefault ドメインに属することになります。

=== Domains ===
Domain はProject、ユーザ、グループの高レベルコンテナです。
Domain は特定のドメインに属している必要があります。
それぞれのDomain はAPI が見える名前が存在するネームスペースを定義します。
Keystone はデフォルトのドメインとして<code>Default</code> を提供しています。<br />

=== 名前の一意性 ===

* Domain Name: グローバルに一意である必要がある
* Role Name: ドメイン内で一意
* User Name: ドメイン内で一意
* Project Name: ドメイン内で一意
* Group Name: ドメイン内で一意

Domain は、OpenStack リソースに対する管理を委任する方法として利用できます。
ユーザは、もし適切な権限が与えられれば、ドメインをまたいで内部のリソースにアクセスすることができます。

== Assignment ==
Assignment サービスは<code>role</code> と<code>role assignments</code> を提供します。

=== Roles ===
Roles は、ユーザが取得できるレベルを定義します。
Roles は、Domain またはProject レベルまで昇格することができます。<br />
一つのRole は、個々のユーザやグループレベルに割当することができます。
Role 名は、Domain 内で一意である必要があります。

=== Role Assignments ===
ロール、リソース、およびIDを持つ3タプル。

=== Token ===
既に認証されたユーザのトーケンの管理と検証を行います。

=== Catalog ===

エンドポイントディスカバリのために、エンドポイントレジストリを提供します。

== Application Construction ==

Keystone は、サービスのフロントエンドです。<br />
// 詳細は、公式ドキュメントに書かれているが、割愛

== Service Backends ==

個々のサービスは、様々な環境とニーズにマッチするように設定されています。
バックエンドのサービスは<code>keystone.conf</code> ファイルに定義されています。<br /><br />

抽象化したクラスとして、それぞれのサービスが定義されています。
これらのクラスは、<code>base.py</code> として、保存されます。<br />
// 詳細なサービスのクラスの列挙は割愛します

== Templated Backend ==
事前にテンプレートとして用意された定義に対して、一般的なユースケースに対して設計されたものです。

== データモデル ==
Keystone は、複数のバックエンドスタイルに対応できるように設計されました。
データモデルによって、我々が想定する以上の種類のデータが、バックエンドに渡せるようになりました。<br /><br />

主なデータタイプとしては、以下の通りです。

* User: ユーザは、1 つ以上のドメインやプロジェクトに対応した、認証情報を持ちます
* Group: 1 つ以上のドメインやプロジェクトに対応した、ユーザのコレクションです
* Project: 1 つ以上のユーザを含んだ所有権のグループです
* Domain: ユーザ、グループ、プロジェクトを含むOpenStack の所有者の単位です
* Role: 複数のユーザプロジェクトのメタデータです
* Token: ユーザまたはユーザとプロジェクトを識別するための情報です
* Extras: ユーザプロジェクトペアの、key-valu の組み合わせです
* Rule: 動作をするための、要求のセットです

== CRUD へのアプローチ ==
// 割愛

== 認証へのアプローチ(ポリシー) ==
システム内に存在するサービスコンポーネントは、ユーザがそのアクションを起こすのに、十分な権限があるかどうかを要求します。<br />

Keystone では、チャックされる認可のレベルとしては、以下のものがあります。

* ユーザが管理者かどうか
* 対象のユーザが、参照中のユーザかどうか

== Rules ==
認証情報が、ルールにマッチするかどうかを検証します。<br />
// その他の説明については割愛

== RBAC 可能性 ==
認可の他の方法として、そのロールに設定された権限をベースにしたアクションベースの認可です。

== 認証のアプローチ ==
Keystone は、<code>keystone.auth.plugins.base</code> を継承した、いくつかの認証プラグインを提供します。
以下は、使用可能なプラグイン一覧です。

* keystone.auth.plugins.external.Base
* keystone.auth.plugins.mapped.Mapped
* keystone.auth.plugins.oauth1.OAuth
* keystone.auth.plugins.password.Password
* keystone.auth.plugins.token.Token
* keystone.auth.plugins.totp.TOTP

プロジェクトID 等を、コマンドラインから設定する場合は、環境変数を設定できます。

<syntaxhighlight lang="console">
export OS_PROJECT_DOMAIN_ID=1789d1
export OS_USER_DOMAIN_NAME=acme
export OS_USERNAME=userA
export OS_PASSWORD=secretsecret
export OS_PROJECT_NAME=project-x
</syntaxhighlight>

== スコープとは ==
ユーザがアクセスしようとしているリソースの範囲(project, domain, system など)です。<br />
例えば、<code>project-scoped</code>, <code>domain-scoped</code>, <code>domain-related</code> 等のスコープがあります。

== Mapping of policy target to API ==
API のエンドポイント一覧は、以下のURL に記載されています。

; Mapping of policy target to API
: https://docs.openstack.org/keystone/wallaby/getting-started/policy_mapping.html

; keystone
: https://docs.openstack.org/keystone/wallaby/api/modules.html

= Keystone =

; Keystone Installation Tutorial
: https://docs.openstack.org/keystone/wallaby/install/

; Manage projects, users, and roles
: https://docs.openstack.org/keystone/pike/admin/cli-manage-projects-users-and-roles.html

