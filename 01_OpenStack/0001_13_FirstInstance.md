= 初めてのインスタンス =

* ルーターの作成
* サブネットの作成
* ルーターにサブネットマスクの追加
* セキュリティグループの作成
  -> "openstack security group list --project service" とすると、既に作成済みのセキュリティグループを見れる？

// 内部サブネットと、外部サブネット両方作って、両方をルータに登録する必要ある？

== OVS の場合の対応 ==
OVS の場合、下記の対応を実施してください。  
// 以下の対応が、現状必要か？  

; [OVN] Update of OVN to 2.13.0-28 causing ovn-controller br-int connection failures due required OpenFlow 1.5
: https://bugzilla.redhat.com/show_bug.cgi?id=1843811

OpenFlow のバージョンを指定します。

<syntaxhighlight lang="console">
openstack-controller-node01 # ovs-vsctl set bridge br-int protocols=OpenFlow13,OpenFlow15
openstack-controller-node01 # #ovs-vsctl --may-exist add-br br-provider -- add bridge br-provider protocols OpenFlow15
</syntaxhighlight>

provider セグメントのインタフェースを登録します。

<syntaxhighlight lang="console">
openstack-controller-node01 # ovs-vsctl set open . external-ids:ovn-bridge-mappings=provider:br-provider
openstack-controller-node01 # ovs-vsctl --may-exist add-port br-provider enp1s0
</syntaxhighlight>

== サブネットマスクの作成 ==

<syntaxhighlight lang="console">
openstack-controller-node01 # . ./admin-openrc
openstack-controller-node01 # # Linux bridge を使っている場合
openstack-controller-node01 # openstack network create --mtu 1400 private
openstack-controller-node01 # # OVN を使っている場合
openstack-controller-node01 # openstack network create --mtu 1400 --provider-network-type geneve --provider-segment 101 private

openstack-controller-node01 # openstack network list
+--------------------------------------+---------+---------+
| ID                                   | Name    | Subnets |
+--------------------------------------+---------+---------+
| 4b682409-efa4-4c36-bd8e-b75fdafb23e1 | private |         |
+--------------------------------------+---------+---------+

openstack-controller-node01 # openstack subnet create --network private \
                                  --allocation-pool start=192.168.3.50,end=192.168.3.200 \
                                  --dns-nameserver 192.168.1.1 --dns-nameserver 8.8.8.8 \
                                  --subnet-range 192.168.3.0/24 private_subnet

openstack-controller-node01 # # Create public(provider) network
openstack-controller-node01 # openstack network create --provider-network-type flat --provider-physical-network provider --external public

openstack-controller-node01 # # Define subnet for the public network.
openstack-controller-node01 # openstack subnet create --network public --allocation-pool start=192.168.1.160,end=192.168.1.200 --no-dhcp --subnet-range 192.168.1.0/24 public_subnet
openstack-controller-node01 # openstack subnet list
+--------------------------------------+----------------+--------------------------------------+----------------+
| ID                                   | Name           | Network                              | Subnet         |
+--------------------------------------+----------------+--------------------------------------+----------------+
| 396c41a6-fada-440d-81d7-01fec003d22d | public_subnet  | 505f3926-3215-4b1d-9659-7e4250980da9 | 192.168.1.0/24 |
| 483d48df-6991-46e0-9a41-81f96bbe264c | private_subnet | 4b682409-efa4-4c36-bd8e-b75fdafb23e1 | 192.168.3.0/24 |
+--------------------------------------+----------------+--------------------------------------+----------------+

openstack-controller-node01 # openstack router create private_router
openstack-controller-node01 # # 次のコマンドで、namespace にqrouter が作成される

openstack-controller-node01 # ## IP アドレスを指定しないでrouter を設定する場合
openstack-controller-node01 # openstack router set --external-gateway public private_router
openstack-controller-node01 # ## IP アドレスを指定してrouter を設定する場合
openstack-controller-node01 # openstack router set --external-gateway public --fixed-ip subnet=192.168.1.0/24,ip-address=192.168.1.254 private_router

openstack-controller-node01 # openstack router add subnet private_router private_subnet
openstack-controller-node01 # openstack router list
</syntaxhighlight>

下記のコマンドを実行して、外部のネットワークと疎通をする<code>br-provider</code> インタフェースを有効化します。



Linux の物理ノードのブリッジ(br0)に、ルータのTerminal Access Point (TAP) を追加します。<br />
ルータはLinux のネームスペースを使って作成されているため、ワーカーノード上で<code>ip netns</code> コマンドを実行することでも、ルータが作成されていることを確認できます。

* openstack-controller-node01 (Linux Bridge の場合)
<syntaxhighlight lang="console">
openstack-controller-node01 # ip netns show
qrouter-72a3c497-605e-4b9d-98c0-94a887956cfc (id: 1)
qdhcp-ba7107fb-d019-4baa-bebe-e79b2c813d31 (id: 0)
</syntaxhighlight>

上記のように2件のネームスペースが表示されます。
1 つはDHCP サーバのネームスペースで、もう一つの<code>qrouter-</code> で始まるネームスペースがルーターのネームスペースです。<br /><br />

ここで、ルーターのネームスペースからインターネット接続ができることを確認してみましょう。
<code>ip netns exec ネームスペース コマンド</code> を実行することで、指定したネームスペース上で任意のコマンドを実行することができます。

<syntaxhighlight lang="console">
openstack-controller-node01 # ip netns exec qrouter-72a3c497-605e-4b9d-98c0-94a887956cfc ping -c 1 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=114 time=11.2 ms
......
</syntaxhighlight>

上記のように、インターネット接続の確認ができれば、ネットワークの設定はほぼ完了です。<br /><br />

CirrOS を使い、イメージをOpenStack に登録します。

* openstack-controller-node01
<syntaxhighlight lang="console">
openstack-controller-node01 # wget http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img
openstack-controller-node01 # openstack image create --disk-format qcow2 \
                                  --container-format bare --public \
                                  --file ./cirros-0.5.1-x86_64-disk.img "Cirros-0.5.1"

openstack-controller-node01 # openstack image list
+--------------------------------------+--------------+--------+
| ID                                   | Name         | Status |
+--------------------------------------+--------------+--------+
| 75393e7b-5a46-44d4-9045-ac0d6bc70499 | Cirros-0.5.1 | active |
| 4e35442a-00fe-4140-be79-1df1dfa2d127 | cirros       | active |
+--------------------------------------+--------------+--------+
</syntaxhighlight>

次に、インスタンスのフレーバーを定義します。
複数定義するのが一般的ですが、今回はm1.tiny の1 件だけにします。

<syntaxhighlight lang="console">
openstack-controller-node01 # openstack flavor create --id 1 --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack-controller-node01 # openstack flavor list
+----+-----------+------+------+-----------+-------+-----------+
| ID | Name      |  RAM | Disk | Ephemeral | VCPUs | Is Public |
+----+-----------+------+------+-----------+-------+-----------+
| 1  | m1.tiny   |  512 |    1 |         0 |     1 | True      |
+----+-----------+------+------+-----------+-------+-----------+
</syntaxhighlight>

次に、セキュリティグループを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 # openstack security group create permit_all --description "Allow all ports"
openstack-controller-node01 # openstack security group rule create --protocol TCP --dst-port 1:65535 --remote-ip 0.0.0.0/0 permit_all
openstack-controller-node01 # openstack security group rule create --protocol ICMP --remote-ip 0.0.0.0/0 permit_all

openstack-controller-node01 # # 22, 80, 443 といった、基本的なポートのみのアクセス許可をするセキュリティグループを作成します
openstack-controller-node01 # openstack security group create limited_access --description "Allow base ports"
openstack-controller-node01 # openstack security group rule create --protocol ICMP --remote-ip 0.0.0.0/0 limited_access
openstack-controller-node01 # openstack security group rule create --protocol TCP --dst-port 22 --remote-ip 0.0.0.0/0 limited_access
openstack-controller-node01 # openstack security group rule create --protocol TCP --dst-port 80 --remote-ip 0.0.0.0/0 limited_access
openstack-controller-node01 # openstack security group rule create --protocol TCP --dst-port 443 --remote-ip 0.0.0.0/0 limited_access


openstack-controller-node01 # openstack security group list
+--------------------------------------+----------------+------------------------+----------------------------------+------+
| ID                                   | Name           | Description            | Project                          | Tags |
+--------------------------------------+----------------+------------------------+----------------------------------+------+
| 685d0c77-e29b-490a-85b5-e61314f7a67f | default        | Default security group |                                  | []   |
| 6d4c5a34-0780-419a-a9e2-ee12a7cd2b6c | default        | Default security group | df9c9628429a4e32b8c84728aa37e42d | []   |
| c213b87e-4679-4621-9022-183b47b7f501 | permit_all     | Allow all ports        | df9c9628429a4e32b8c84728aa37e42d | []   |
| dee87126-1b92-4820-99b7-72a2ead37932 | default        | Default security group | 40d85255446e46c8b7beebf6f1325e05 | []   |
| e40760dc-bb6b-4657-8d42-c7459343f52d | limited_access | Allow base ports       | df9c9628429a4e32b8c84728aa37e42d | []   |
+--------------------------------------+----------------+------------------------+----------------------------------+------+

openstack-controller-node01 # # セキュリティグループの内容を確認します
openstack-controller-node01 # openstack security group show permit_all
+-----------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field           | Value                                                                                                                                                                                                 |
+-----------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| created_at      | 2021-05-18T15:09:17Z                                                                                                                                                                                  |
| description     | Allow all ports                                                                                                                                                                                       |
| id              | c213b87e-4679-4621-9022-183b47b7f501                                                                                                                                                                  |
| name            | permit_all                                                                                                                                                                                            |
| project_id      | df9c9628429a4e32b8c84728aa37e42d                                                                                                                                                                      |
| revision_number | 3                                                                                                                                                                                                     |
| rules           | created_at='2021-05-18T15:09:40Z', direction='ingress', ethertype='IPv4', id='05e635cc-1744-4a2b-9055-7907f7bbd179', protocol='tcp', remote_ip_prefix='0.0.0.0/0', updated_at='2021-05-18T15:09:40Z'  |
|                 | created_at='2021-05-18T15:09:17Z', direction='egress', ethertype='IPv6', id='231e5b13-01de-46b9-a1d7-fc3fc654f3eb', updated_at='2021-05-18T15:09:17Z'                                                 |
|                 | created_at='2021-05-18T15:09:17Z', direction='egress', ethertype='IPv4', id='4f1ab3fe-f485-4fe6-bb12-ebdab338a19f', updated_at='2021-05-18T15:09:17Z'                                                 |
|                 | created_at='2021-05-18T15:10:11Z', direction='ingress', ethertype='IPv4', id='9b5c021e-8229-4767-ac62-23448cf80c5b', protocol='icmp', remote_ip_prefix='0.0.0.0/0', updated_at='2021-05-18T15:10:11Z' |
| stateful        | True                                                                                                                                                                                                  |
| tags            | []                                                                                                                                                                                                    |
| updated_at      | 2021-05-18T15:10:11Z                                                                                                                                                                                  |
+-----------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
openstack-controller-node01 # openstack security group show limited_access
+-----------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Field           | Value                                                                                                                                                                                                                                            |
+-----------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| created_at      | 2021-05-18T15:15:16Z                                                                                                                                                                                                                             |
| description     | Allow base ports                                                                                                                                                                                                                                 |
| id              | e40760dc-bb6b-4657-8d42-c7459343f52d                                                                                                                                                                                                             |
| name            | limited_access                                                                                                                                                                                                                                   |
| project_id      | df9c9628429a4e32b8c84728aa37e42d                                                                                                                                                                                                                 |
| revision_number | 5                                                                                                                                                                                                                                                |
| rules           | created_at='2021-05-18T15:15:30Z', direction='ingress', ethertype='IPv4', id='0311e05e-ac89-4e05-a4b6-946ee96c47d3', port_range_max='80', port_range_min='80', protocol='tcp', remote_ip_prefix='0.0.0.0/0', updated_at='2021-05-18T15:15:30Z'   |
|                 | created_at='2021-05-18T15:15:34Z', direction='ingress', ethertype='IPv4', id='44e42e9a-248d-41bf-99a6-e5d9a567daa0', port_range_max='443', port_range_min='443', protocol='tcp', remote_ip_prefix='0.0.0.0/0', updated_at='2021-05-18T15:15:34Z' |
|                 | created_at='2021-05-18T15:15:21Z', direction='ingress', ethertype='IPv4', id='5ab8677a-a058-4249-bf39-b823640830dd', protocol='icmp', remote_ip_prefix='0.0.0.0/0', updated_at='2021-05-18T15:15:21Z'                                            |
|                 | created_at='2021-05-18T15:15:16Z', direction='egress', ethertype='IPv6', id='6e2475f1-16d0-463e-be25-ba164436da7d', updated_at='2021-05-18T15:15:16Z'                                                                                            |
|                 | created_at='2021-05-18T15:15:26Z', direction='ingress', ethertype='IPv4', id='a26f8180-2ad4-4d67-8e98-029814fc00bb', port_range_max='22', port_range_min='22', protocol='tcp', remote_ip_prefix='0.0.0.0/0', updated_at='2021-05-18T15:15:26Z'   |
|                 | created_at='2021-05-18T15:15:16Z', direction='egress', ethertype='IPv4', id='dc58b3ef-531c-415c-b73e-6b719624e46f', updated_at='2021-05-18T15:15:16Z'                                                                                            |
| stateful        | True                                                                                                                                                                                                                                             |
| tags            | []                                                                                                                                                                                                                                               |
| updated_at      | 2021-05-18T15:15:34Z                                                                                                                                                                                                                             |
+-----------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
</syntaxhighlight>

SSH ログイン用の公開鍵ペアを作成して、登録します。

<syntaxhighlight lang="console">
openstack-controller-node01 # ssh-keygen -t rsa -b 4096 -f ~/.ssh/example_openstack_id_rsa
openstack-controller-node01 # openstack keypair create --public-key ~/.ssh/example_openstack_id_rsa.pub admin
+-------------+-------------------------------------------------+
| Field       | Value                                           |
+-------------+-------------------------------------------------+
| fingerprint | c1:fd:23:4b:25:d4:06:40:28:17:c3:28:01:06:ec:02 |
| name        | admin                                           |
| user_id     | 91c5919b42a44193b5dda4997c16c65f                |
+-------------+-------------------------------------------------+

openstack-controller-node01 # openstack keypair list
+-------+-------------------------------------------------+
| Name  | Fingerprint                                     |
+-------+-------------------------------------------------+
| admin | c1:fd:23:4b:25:d4:06:40:28:17:c3:28:01:06:ec:02 |
+-------+-------------------------------------------------+
</syntaxhighlight>

<syntaxhighlight lang="console">
openstack-controller-node01 # openstack server create \
                                  --flavor m1.tiny --image "Cirros-0.5.1" \
                                  --key-name admin --security-group permit_all \
                                  --network private mycirros

openstack-controller-node01 # openstack server list
+--------------------------------------+----------+--------+-----------------------+--------------+---------+
| ID                                   | Name     | Status | Networks              | Image        | Flavor  |
+--------------------------------------+----------+--------+-----------------------+--------------+---------+
| 65b94db6-5814-4bf3-992e-e7b3a8190fdc | mycirros | ACTIVE | private=192.168.3.124 | Cirros-0.5.1 | m1.tiny |
+--------------------------------------+----------+--------+-----------------------+--------------+---------+
</syntaxhighlight>

= ネットワーク構成の確認(Linux Bridge の場合) =
仮想ネットワークがどのようになっているか詳細に確認してみましょう。<br />
ルータネームスペース上でip コマンドを実行して、ルーターが持っているネットワークインタフェースを確認します。

* openstack-controller-node01
<syntaxhighlight lang="console">
openstack-controller-node01 # ip netns ls
qrouter-72a3c497-605e-4b9d-98c0-94a887956cfc (id: 1)
qdhcp-ba7107fb-d019-4baa-bebe-e79b2c813d31 (id: 0)
</syntaxhighlight>

Controller ノード上でワーカーノードと、ネームスペース(router)、birdge インタフェースの状態を見てみましょう。

* openstack-controller-node01 のインタフェース確認
<syntaxhighlight lang="console">
openstack-controller-node01 # # コントローラノードのインタフェース
openstack-controller-node01 # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master brq2f2c0f38-c5 state UP group default qlen 1000
    link/ether 52:54:00:e3:f0:c0 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::5054:ff:fee3:f0c0/64 scope link
       valid_lft forever preferred_lft forever
3: enp9s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:80:bb:76 brd ff:ff:ff:ff:ff:ff
    inet 192.168.2.71/24 brd 192.168.2.255 scope global enp9s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe80:bb76/64 scope link
       valid_lft forever preferred_lft forever
6: tap76ff2fd2-90@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue master brqba7107fb-d0 state UP group default qlen 1000
    link/ether ae:63:d3:4b:e9:d4 brd ff:ff:ff:ff:ff:ff link-netns qdhcp-ba7107fb-d019-4baa-bebe-e79b2c813d31
7: vxlan-1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue master brqba7107fb-d0 state UNKNOWN group default qlen 1000
    link/ether 46:33:fa:9f:20:18 brd ff:ff:ff:ff:ff:ff
8: brqba7107fb-d0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether 0a:5e:d1:91:af:b7 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::ec5c:28ff:fee5:1d77/64 scope link
       valid_lft forever preferred_lft forever
9: tap92901b3e-ab@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue master brqba7107fb-d0 state UP group default qlen 1000
    link/ether 0a:5e:d1:91:af:b7 brd ff:ff:ff:ff:ff:ff link-netns qrouter-72a3c497-605e-4b9d-98c0-94a887956cfc
10: tap16813768-d6@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master brq2f2c0f38-c5 state UP group default qlen 1000
    link/ether 56:c6:f6:11:f5:b8 brd ff:ff:ff:ff:ff:ff link-netns qrouter-72a3c497-605e-4b9d-98c0-94a887956cfc
11: brq2f2c0f38-c5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 52:54:00:e3:f0:c0 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::ce9:a2ff:fed9:90a4/64 scope link
       valid_lft forever preferred_lft forever

openstack-controller-node01 # # ネームスペース(qrouter)のインタフェース
openstack-controller-node01 # ip netns exec qrouter-72a3c497-605e-4b9d-98c0-94a887956cfc ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: qr-92901b3e-ab@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether fa:16:3e:6a:93:b9 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.3.1/24 brd 192.168.3.255 scope global qr-92901b3e-ab
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:fe6a:93b9/64 scope link
       valid_lft forever preferred_lft forever
3: qg-16813768-d6@if10: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether fa:16:3e:9e:85:ba brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.1.172/24 brd 192.168.1.255 scope global qg-16813768-d6
       valid_lft forever preferred_lft forever
    inet6 fe80::f816:3eff:fe9e:85ba/64 scope link
       valid_lft forever preferred_lft forever

openstack-controller-node01 # # コントローラノード
openstack-controller-node01 # brctl show
bridge name             bridge id               STP enabled     interfaces
brq2f2c0f38-c5          8000.525400e3f0c0       no              enp1s0
                                                                tap16813768-d6
brqba7107fb-d0          8000.0a5ed191afb7       no              tap76ff2fd2-90
                                                                tap92901b3e-ab
                                                                vxlan-1
</syntaxhighlight>

TAP インタフェースが作成されており、それが<code>qrouter-90226685-a07e-424a-90de-c2536c6e569c</code> 名前空間に接続されていることが確認できます。
また<code>tap...</code>インタフェースと、ネームスペース上のインタフェース名の名前の一部は、一致するようになっており、対応関係がわかるようになっています。<br />
(例: tap16813768-d6 -> qg-16813768-d6)<br /><br />

次にコンピュートノードのインタフェースの状態を確認してみましょう。

* openstack-controller-node01
<syntaxhighlight lang="console">
openstack-compute-node01 # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:3e:a6:a9 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::5054:ff:fe3e:a6a9/64 scope link
       valid_lft forever preferred_lft forever
3: enp9s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:37:f1:68 brd ff:ff:ff:ff:ff:ff
    inet 192.168.2.72/24 brd 192.168.2.255 scope global enp9s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe37:f168/64 scope link
       valid_lft forever preferred_lft forever
4: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 52:54:00:57:6b:6b brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
       valid_lft forever preferred_lft forever
5: virbr0-nic: <BROADCAST,MULTICAST> mtu 1500 qdisc fq_codel master virbr0 state DOWN group default qlen 1000
    link/ether 52:54:00:57:6b:6b brd ff:ff:ff:ff:ff:ff
8: brqba7107fb-d0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default qlen 1000
    link/ether 12:27:3c:f5:25:30 brd ff:ff:ff:ff:ff:ff
9: tapcfda1afb-b4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc fq_codel master brqba7107fb-d0 state UNKNOWN group default qlen 1000
    link/ether fe:16:3e:88:c9:85 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::fc16:3eff:fe88:c985/64 scope link
       valid_lft forever preferred_lft forever
10: vxlan-1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue master brqba7107fb-d0 state UNKNOWN group default qlen 1000
    link/ether 12:27:3c:f5:25:30 brd ff:ff:ff:ff:ff:ff

openstack-compute-node01 # brctl show
bridge name             bridge id               STP enabled     interfaces
brqba7107fb-d0          8000.12273cf52530       no              tapcfda1afb-b4
                                                                vxlan-1
virbr0                  8000.525400576b6b       yes             virbr0-nic
</syntaxhighlight>

上記の出力結果から、物理/仮想ネットワークを含めた全体の構成は以下の図のようになります。<br />

// [TODO:]  

; Install OpenStack Victoria on CentOS 8 With Packstack
: https://computingforgeeks.com/install-openstack-victoria-on-centos/

; How To add Glance Cloud images to OpenStack
: https://computingforgeeks.com/adding-images-openstack-glance/

; Login credentials of Ubuntu Cloud server image
: https://stackoverflow.com/questions/29137679/login-credentials-of-ubuntu-cloud-server-image

