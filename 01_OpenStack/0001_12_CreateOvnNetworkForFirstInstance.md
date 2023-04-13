= 概要 =
OVN 環境で、neutron ネットワーク環境を構築する場合の手順について説明していきます。

以下の名前で作成していきたいと思います。

外部セグメント用ブリッジインタフェース名
br-provider

内部セグメント用ブリッジインタフェース名

== OpenFlow プロトコルバージョンの指定 ==
各コントローラノード、ネットワークノード、コンピュートノードで、インテグレーションスイッチ br-int のOpenFlow プロトコルのバージョンを指定します。

* openstack-controller-node01, openstack-compute-node01
<syntaxhighlight lang="console">
# ovs-vsctl add bridge br-int protocols OpenFlow15
</syntaxhighlight>

この対応は、2021年07月現在、下記リンクのエラー対応のため実施しています。
将来的には、この対応は不要になる可能性があります。

; [OVN] Update of OVN to 2.13.0-28 causing ovn-controller br-int connection failures due required OpenFlow 1.5
: https://bugzilla.redhat.com/show_bug.cgi?id=1843811

== 外部接続用のブリッジインタフェース作成 ==
各コンピュートノード上で、外部接続用のブリッジインタフェースを作成します。
各コンピュータノード上のVM は、Floating IP を持つことで、ネットワークセグメントを中継することなく、各コンピュータノード上の物理インタフェースから直接外部へパケットを送受信することになります。

# DHCP エージェントを起動する(不要？)。
# <syntaxhighlight lang="console">
# openstack-controller-node01 # systemctl rsetart neutron-dhcp-agent.service
# openstack-controller-node01 # openstack network agent list
# </syntaxhighlight>

<syntaxhighlight lang="console">
openstack-compute-node01 # ##ovs-vsctl --may-exist add-br br-provider -- set bridge br-provider protocols=OpenFlow13,OpenFlow15
openstack-compute-node01 # ovs-vsctl --may-exist add-br br-provider -- add bridge br-provider protocols OpenFlow15
openstack-compute-node01 # ovs-vsctl set open . external-ids:ovn-bridge-mappings=provider:br-provider
openstack-compute-node01 # ovs-vsctl --may-exist add-port br-provider enp1s0
</syntaxhighlight>

次に、コントローラノード上で、ネットワークを作成します。

<syntaxhighlight lang="console">
openstack-controller-node01 # # Create provider network
openstack-controller-node01 # ovs-vsctl set open . external-ids:ovn-cms-options="enable-chassis-as-gw"
openstack-controller-node01 # . ./admin-openrc
openstack-controller-node01 # openstack network create --external --share --provider-physical-network provider --provider-network-type flat provider
openstack-controller-node01 # openstack subnet create --network provider --subnet-range \
                                  192.168.1.0/24 --allocation-pool start=192.168.1.160,end=192.168.1.199 \
                                  --dns-nameserver 8.8.8.8 --gateway 192.168.1.1 provider-v4

openstack-controller-node01 # ###openstack network create --mtu 1400 --provider-network-type geneve --provider-segment 11 private
openstack-controller-node01 # #openstack subnet create --network private --subnet-range 192.168.3.0/24 --dns-nameserver 8.8.8.8 private_subnet
openstack-controller-node01 # ###openstack subnet create --network private \
                              --subnet-range 192.168.3.0/24 --dns-nameserver 8.8.8.8 private_subnet

openstack-controller-node01 # ###openstack router create private_router
openstack-controller-node01 # ###openstack router set --external-gateway provider private_router
openstack-controller-node01 # ###openstack router add subnet private_router private_subnet
</syntaxhighlight>

= 参照 =
; Reference architecture
: https://docs.openstack.org/networking-ovn/queens/admin/refarch/refarch.html

