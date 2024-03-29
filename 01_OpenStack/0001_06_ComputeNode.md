= Compute ノードのインストールと設定 =

; Install and configure a compute node
: https://docs.openstack.org/nova/yoga/install/compute-install.html

Compute ノードのインストールと設定について説明していきます。
Compute ノードは、インスタンスやVM をデプロイするために、いくつかのハイパーバイザをサポートしています。
ここでは、簡略化するために、QEMU とKVM を使ってやっていきます。
また、Compute ノードはController ノードとは別のマシン上に構築していくことにします。

; Example archtecture
: https://docs.openstack.org/nova/wallaby/install/overview.html#overview-example-architectures

<syntaxhighlight lang="console">
openstack-compute-node01 ~# apt-get install -y nova-compute
</syntaxhighlight>

* /etc/nova/nova.conf @ openstack-compute-node01
<syntaxhighlight lang="console">
[DEFAULT]
# ...
transport_url = rabbit://openstack:p@ssw0rd@openstack-controller-node01
# ...

[api]
# ...
auth_strategy = keystone
my_ip = 192.168.2.72
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
# ...
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = $my_ip
novncproxy_base_url = http://openstack-controller-node01:6080/vnc_auto.html
# ...

[glance]
# ...
api_servers = http://openstack-controller-node01:9292
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

次に、仮想マシンのための、ハードウェアアクセラレータの有無を確認します。
以下のコマンドを実行して、1 以上の値が表示されれば、それをサポートしています。
ハードウェアアクセラレーションをサポートしている場合、インスタンスやVM を起動させるための追加の設定は必要ありません。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# egrep -c '(vmx|svm)' /proc/cpuinfo
2
</syntaxhighlight>

もしサポートしていない場合は、KVM の変わりにQEMU を使うように設定する必要があります(説明は割愛 https://docs.openstack.org/nova/wallaby/install/compute-install-ubuntu.html#finalize-installation )。<br /><br />

設定が完了したら、<code>nova-compute</code> を再起動します。

<syntaxhighlight lang="console">
openstack-compute-node01 ~# systemctl restart nova-compute
</syntaxhighlight>

== Compute ノードをcell データベースに追加します ==

以下のコマンドは、```コントローラノード(openstack-controller-node01)``` で実行します。

# // この手順は必要？
# <syntaxhighlight lang="console">
# openstack-controller-node01 ~# . ./admin-openrc
# 
# openstack-controller-node01 ~# openstack compute service list --service nova-compute
# +----+--------------+--------------------------------+------+---------+-------+----------------------------+
# | ID | Binary       | Host                           | Zone | Status  | State | Updated At                 |
# +----+--------------+--------------------------------+------+---------+-------+----------------------------+
# |  6 | nova-compute | openstack-block-storage-node01 | nova | enabled | up    | 2021-05-03T13:59:10.000000 |
# +----+--------------+--------------------------------+------+---------+-------+----------------------------+
# </syntaxhighlight>

Compute ホストの検索を行います。

<syntaxhighlight lang="console">
openstack-controller-node01 ~# su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
Found 2 cell mappings.
Skipping cell0 since it does not contain hosts.
Getting computes from cell 'cell1': 89df27af-d35f-4248-b15c-eea9fc91fba4
Found 0 unmapped computes in cell: 89df27af-d35f-4248-b15c-eea9fc91fba4
</syntaxhighlight>

上記のように確認できれば成功です。

== Compute ノード追加時の対応 ==

もし、クラスタに新しいCompute ノードを追加したら、Controller ノードで<code>nova-manage cell_v2 discover_hosts</code> をコントローラノードで実行する必要があります。
この操作によって、新しいCompute ノードがクラスタに追加されます。
もしくは、<code>/etc/nova/nova.conf</code> ファイルに、インターバルを設定してください。

* /etc/nova/nova.conf @ openstack-controller-node01
<syntaxhighlight lang="text">
[scheduler]
discover_hosts_in_cells_interval = 300
</syntaxhighlight>

