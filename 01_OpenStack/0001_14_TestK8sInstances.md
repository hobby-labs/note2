# 必要なパッケージのインストール

```
k8s-(master|node) # cat << 'EOF' > /etc/apt/apt.conf.d/01proxy
Acquire::HTTP::Proxy "http://172.31.0.11:3142";
Acquire::HTTPS::Proxy "false";
EOF
```

```
k8s-(master|node) # apt-get update
```

```
k8s-(master|node) # swapoff -a
k8s-(master|node) # sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

# /etc/hosts の設定
各ノードに`/etc/hosts` を設定します。

* /etc/hosts
```
192.168.255.11    dev-k8s-node01 dev-k8s-master01
192.168.255.12    dev-k8s-node02
192.168.255.13    dev-k8s-node03
192.168.255.14    dev-k8s-node04
192.168.255.15    dev-k8s-node05
192.168.255.16    dev-k8s-node06
```

# IPv4 bridge の設定

```
k8s-(master|node) # cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

```
k8s-(master|node) # sudo modprobe overlay
k8s-(master|node) # sudo modprobe br_netfilter

k8s-(master|node) # # sysctl params required by setup, params persist across reboots

k8s-(master|node) # cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

k8s-(master|node) # # Apply sysctl params without reboot
k8s-(master|node) # sudo sysctl --system
```

# Kubernetes インストールに必要な準備
今回は、swap 領域はマウントされていない想定で作業を進めます。

```
k8s-(master|node) # curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

k8s-(master|node) # cat << 'EOF' > /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main
EOF

k8s-(master|node) # apt-get update

k8s-(master|node) # apt-get install -y kubelet kubeadm kubectl
```

# Docker のインストール

```
k8s-(master|node) # apt-get install -y docker.io
k8s-(master|node) # mkdir /etc/containerd
k8s-(master|node) # sh -c "containerd config default > /etc/containerd/config.toml"
k8s-(master|node) # sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
k8s-(master|node) # systemctl restart containerd.service
k8s-(master|node) # systemctl restart kubelet.service
k8s-(master|node) # systemctl enable kubelet.service
```

# Master ノードでKubernetes クラスタの初期化

```
k8s-master # kubeadm config images pull
k8s-master # kubeadm init --pod-network-cidr=10.10.0.0/16
```

今後一般ユーザでクラスタを管理する場合は下記のようにして、事前にkubeconfig を取得しておきます。

```
k8s-master $ # 一般ユーザで実施
k8s-master $ mkdir -p $HOME/.kube
k8s-master $ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
k8s-master $ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

# Calico オペレータのデプロイ

```
k8s-master # kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
```

```
k8s-master # curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml -O
k8s-master # sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 10.10.0.0\/16/g' custom-resources.yaml
k8s-master # kubectl create -f custom-resources.yaml
```

# Cluster にWorker ノードを追加する

```
k8s-nodeXX # kubeadm join 172.31.1.11:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

# Cluster の検証

```
k8s-master # kubectl get nodes
NAME             STATUS     ROLES           AGE   VERSION
dev-k8s-node01   NotReady   control-plane   40m   v1.28.2
dev-k8s-node02   NotReady   <none>          23s   v1.28.2
dev-k8s-node03   NotReady   <none>          20s   v1.28.2
dev-k8s-node04   NotReady   <none>          18s   v1.28.2
dev-k8s-node05   NotReady   <none>          17s   v1.28.2
dev-k8s-node06   NotReady   <none>          16s   v1.28.2

k8s-master # kubectl get pods -A
```

# 参考
* [https://www.cherryservers.com/blog/install-kubernetes-on-ubuntu](How to Install Kubernetes on Ubuntu 22.04 | Step-by-Step)
* [https://kubernetes.io/blog/2019/03/15/kubernetes-setup-using-ansible-and-vagrant/](Kubernetes Setup Using Ansible and Vagrant)
* [https://askubuntu.com/a/1236711](docker ps stuck ... docker install also just hangs)

