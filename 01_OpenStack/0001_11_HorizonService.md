= Horizon =

; Installation Guide(Horizon)
: https://docs.openstack.org/horizon/wallaby/install/

ここでは、コントローラノードにダッシュボード(Horizon)のインストール方法について説明していきます。<br />

Horizon が要求する他サービスは、Identity サービス(Keystone)となっており、Apache HTTP サーバとMemcached を使っていることを前提としています。
Image(Glance)、Compute(Nova)、Networking(Neutron)といった他のサービスと組み合わせて利用することもできます。
また、Object ストレージといったスタンドアロンサービスでも利用することができます。

== システム要件 ==
割愛。

== インストールと設定 ==

; Install and configure for Ubuntu
: https://docs.openstack.org/horizon/wallaby/install/install-ubuntu.html

<syntaxhighlight lang="console">
openstack-controller-node01 ~# apt-get install -y openstack-dashboard
</syntaxhighlight>

<code>/etc/openstack-dashboard/local_settings.py</code> ファイルを開き、ダッシュボードの設定を編集します。

* /etc/openstack-dashboard/local_settings.py
<syntaxhighlight lang="text">
OPENSTACK_HOST = "openstack-controller-node01"
# ......
ALLOWED_HOSTS = '*'
# ......

SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
# ......

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
        'LOCATION': 'openstack-controller-node01:11211',
    }
}
# ......

OPENSTACK_KEYSTONE_URL = "http://%s:5000/identity/v3" % OPENSTACK_HOST
# ......

TIME_ZONE = "UTC"
</syntaxhighlight>

<code>OPENSTACK_HOST</code> には、コントローラノードを指定します。
<code>ALLOWED_HOSTS</code> には、アクセスを許可するホストを指定します。
複数ホストを指定する場合は、配列形式で<code>['foo.example.com', 'bar.example.com']</code>と指定することができます。
<code>'*'</code> を指定して、すべてのホストからのアクセスを許可することもできますが、セキュリティリスクを伴うので、商用環境などでは、しっかりと設定したほうが良いでしょう。<br />
<code>SESSION_ENGINE</code>, <code>CACHES</code> を編集して、Memcached セッションストレージサービスを設定します。<br /><br />

// 以下のパラメータは、Ubuntu 20.04 のリポジトリからインストールできるDashboard には、設定必要い？後ほどエラーが出たら設定してみる

<syntaxhighlight lang="text">
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
# ......

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}
# ......

OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"
# ......

OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
# ......

OPENSTACK_NEUTRON_NETWORK = {
    ...
    'enable_router': False,
    'enable_quotas': False,
    'enable_ipv6': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_fip_topology_check': False,
}
# ......
</syntaxhighlight>

<code>/etc/apache2/conf-available/openstack-dashboard.conf</code> ファイルに以下の定義が書かれていない場合は、書くようにしてください。

* /etc/apache2/conf-available/openstack-dashboard.conf
<syntaxhighlight lang="text">
WSGIApplicationGroup %{GLOBAL}
</syntaxhighlight>

== 設定のリロード ==
一連の設定が完了したら、設定をリロードします。

<syntaxhighlight lang="text">
openstack-controller-node01 ~# systemctl reload apache2.service
</syntaxhighlight>

= 検証 =
以下のURL にWeb ブラウザを使ってアクセスしてください。

<syntaxhighlight lang="text">
http://openstack-controller-node01/horizon/
</syntaxhighlight>

ログイン画面が表示されたら、ユーザとパスワードを入力してログインします。

<syntaxhighlight lang="text">
User: admin
Password: p@ssw0rd
</syntaxhighlight>

ログインして、OpenStack ダッシュボードが表示されれば成功です。

