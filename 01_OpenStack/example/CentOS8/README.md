
```
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: enp0s31f6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master ovs-system state UP group default qlen 1000
    link/ether 50:7b:9d:a4:c0:97 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::527b:9dff:fea4:c097/64 scope link
       valid_lft forever preferred_lft forever
3: wlp4s0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 44:85:00:c4:ee:60 brd ff:ff:ff:ff:ff:ff
4: ovs-system: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether b2:c1:49:59:96:b8 brd ff:ff:ff:ff:ff:ff
5: br-int: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 12:53:aa:eb:55:5d brd ff:ff:ff:ff:ff:ff
6: br-ex: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 50:7b:9d:a4:c0:97 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.81/24 brd 192.168.1.255 scope global br-ex
       valid_lft forever preferred_lft forever
    inet6 fe80::240c:5ff:fe60:7148/64 scope link
       valid_lft forever preferred_lft forever

# brctl show
(no output)

# ovn-nbctl show
switch 15dc80ff-6704-4b23-913f-b8fb940a2a66 (neutron-feb216f4-0ee9-420d-a35d-e232007e31b6) (aka private)
    port 37ff0cc3-affb-483f-8b3b-d6cc639cb788
        type: localport
        addresses: ["fa:16:3e:30:43:25 192.168.3.50"]
    port 03ed0e09-dc72-45da-8af7-af668b29d99f
        type: router
        router-port: lrp-03ed0e09-dc72-45da-8af7-af668b29d99f
    port ad8d9d14-139a-4b2b-82dc-30b1a5494923
        addresses: ["fa:16:3e:2a:02:06 192.168.3.172"]
switch a35115af-8257-4e32-8360-525170228e27 (neutron-be5ffce1-2915-4cb5-b5a3-bf423271d805) (aka public)
    port provnet-740de942-9599-4e0b-ab3f-bfafb686ec8a
        type: localnet
        addresses: ["unknown"]
    port f5264017-71dc-409a-8e5a-509c206187c0
        type: localport
        addresses: ["fa:16:3e:ee:48:13"]
    port 108543d9-8829-43d8-9aea-c640c197e3f4
        type: router
        router-port: lrp-108543d9-8829-43d8-9aea-c640c197e3f4
router 1f833737-b711-4f6b-b59b-1b3f45db5081 (neutron-910b44f1-e822-46a2-be45-fd51eb6aa632) (aka private_router)
    port lrp-03ed0e09-dc72-45da-8af7-af668b29d99f
        mac: "fa:16:3e:56:3e:2e"
        networks: ["192.168.3.1/24"]
    port lrp-108543d9-8829-43d8-9aea-c640c197e3f4
        mac: "fa:16:3e:13:01:30"
        networks: ["192.168.1.199/24"]
        gateway chassis: [f435feef-3344-4a5f-8ef1-8da102d17af8]
    nat 4102fa88-4ecd-4851-8363-62ad32b68f6d
        external ip: "192.168.1.199"
        logical ip: "192.168.3.0/24"
        type: "snat"

# openstack subnet list
+--------------------------------------+----------------+--------------------------------------+----------------+
| ID                                   | Name           | Network                              | Subnet         |
+--------------------------------------+----------------+--------------------------------------+----------------+
| ad15b97d-ea1c-4a98-a269-c42a430db0cc | private_subnet | feb216f4-0ee9-420d-a35d-e232007e31b6 | 192.168.3.0/24 |
| b8f205eb-9eb9-429a-99d6-e4fab39ed945 | public_subnet  | be5ffce1-2915-4cb5-b5a3-bf423271d805 | 192.168.1.0/24 |
+--------------------------------------+----------------+--------------------------------------+----------------+

# openstack network list
+--------------------------------------+---------+--------------------------------------+
| ID                                   | Name    | Subnets                              |
+--------------------------------------+---------+--------------------------------------+
| be5ffce1-2915-4cb5-b5a3-bf423271d805 | public  | b8f205eb-9eb9-429a-99d6-e4fab39ed945 |
| feb216f4-0ee9-420d-a35d-e232007e31b6 | private | ad15b97d-ea1c-4a98-a269-c42a430db0cc |
+--------------------------------------+---------+--------------------------------------+
```
