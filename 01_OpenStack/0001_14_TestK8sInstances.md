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
k8s-(master|node) # apt-get install docker.io
```

# 参考
* [https://www.cherryservers.com/blog/install-kubernetes-on-ubuntu](How to Install Kubernetes on Ubuntu 22.04 | Step-by-Step)
* [https://kubernetes.io/blog/2019/03/15/kubernetes-setup-using-ansible-and-vagrant/](Kubernetes Setup Using Ansible and Vagrant)
* [https://askubuntu.com/a/1236711](docker ps stuck ... docker install also just hangs)

