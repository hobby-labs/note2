# 概要
WireGuard を使用して、外部からオフィスのサーバにアクセスするための構成例です。
これは、検証環境として、外部のVPSとオフィスのネットワークをエミュレートしたものです。
ここで構築するものは、全て仮想環境上(KVM)に構築し、実際の構成を模倣することを目的としています。

## Topology

```mermaid
flowchart LR
    internet(("Real internet"))
    gw["Real office router<br/>172.31.0.1"]
    br0{{"br0<br/>172.31.0.0/16<br/>(dummy internet)"}}
    host["Host OS<br/>(test client)<br/>172.31.x.x"]

    subgraph vps_service["VPS (emulated)"]
        vps["vps-wire-guard-01<br/>Alpine Linux<br/>eth0: 172.31.20.199/16<br/>wg0: 10.8.0.1/24 (MTU 1380)<br/>sshd :22222<br/>DNAT :22 :80 :443 → 10.8.0.2"]
    end

    subgraph office["Office (emulated)"]
        or["office-router-01<br/>Alpine Linux<br/>eth0: 172.31.20.198/16 (MTU 1460)<br/>eth1: 192.168.99.1/24<br/>masquerade, no inbound"]
        br2{{"br2<br/>192.168.99.0/24"}}
        os["office-server-01<br/>Ubuntu 26.04<br/>NIC: 192.168.99.11/24<br/>wg0: 10.8.0.2/24 (MTU 1380)<br/>Caddy :80 :443 (tls internal)<br/>sshd :22"]
    end

    internet --- gw --- br0
    host --- br0
    br0 ---|eth0| vps
    br0 ---|eth0| or
    or ---|eth1| br2
    br2 --- os

    os -.->|"WireGuard UDP 51820<br/>(initiated from office)"| vps
    host -->|"HTTPS / SSH<br/>to 172.31.20.199"| vps
    vps -->|"DNAT via wg0"| os
```

図の中の`vps-wire-guard-01`, `office-router-01`, `office-server-01` をKVM で構築していきます。
`Host OS` は、KVM のホストOS で、環境をテストするためのクライアントとしても利用します。

## Packet flow

```mermaid
sequenceDiagram
    participant C as Host OS (client)
    participant V as vps-wire-guard-01
    participant R as office-router-01
    participant S as office-server-01

    S->>R: WireGuard handshake to 172.31.20.199:51820
    Note over R: masquerade 192.168.99.11 → 172.31.20.198
    R->>V: UDP 51820 (tunnel established, keepalive every 25s)

    C->>V: TCP :443 to 172.31.20.199
    Note over V: DNAT → 10.8.0.2 (client IP preserved)
    V->>S: forwarded through wg0 tunnel (via R)
    Note over S: TLS terminated by Caddy
    S-->>V: reply from 10.8.0.2 (policy routing → wg0)
    V-->>C: reply with source 172.31.20.199
```

# 構築手順




