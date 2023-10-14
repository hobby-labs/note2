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
k8s-(master|node) # apt-get install  apt-transport-https ca-certificates curl gnupg-agent software-properties-common
```

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

docker をインストールします。

```
apt-get install docker-ce docker-ce-cli containerd.io
```

```
usermod -aG docker sushi7
```

# Kubernetes インストールに必要な準備
今回は、swap 領域はマウントされていない想定で作業を進めます。

```
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes.gpg

/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
```

# 参考
* [https://www.cherryservers.com/blog/install-kubernetes-on-ubuntu](How to Install Kubernetes on Ubuntu 22.04 | Step-by-Step)
* [https://kubernetes.io/blog/2019/03/15/kubernetes-setup-using-ansible-and-vagrant/](Kubernetes Setup Using Ansible and Vagrant)


