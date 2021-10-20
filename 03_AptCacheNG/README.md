# Docker でapt-cache-ng サーバをたてる

サーバ側の設定

```
$ docker run --name apt-cacher-ng --init -d --restart=always \
  --publish 3142:3142 \
  sameersbn/apt-cacher-ng:3.3-20200524
```

## クライアント側の設定

```
$ docker run --rm -ti ubuntu:20.04 bash
```

`xxx.xxx.xxx.xxx` には、サーバ側のIP アドレスを指定してください。

```
echo 'Acquire::HTTP::Proxy "http://xxx.xxx.xxx.xxx:3142";' >> /etc/apt/apt.conf.d/01proxy
echo 'Acquire::HTTPS::Proxy "false";' >> /etc/apt/apt.conf.d/01proxy
```



