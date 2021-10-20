# Build and run this image with command like below
#
#   docker build -t="tsutomu/apt-cache-ng" .
#   docker run --rm --name apt-cache-ng --hostname apt-cache-ng --publish 3142:3142 -ti tsutomu/apt-cache-ng /bin/bash
FROM ubuntu:20.04
RUN apt-get update && \
    apt-get install -y wget gnupg2 && \
    wget -q https://www.ubuntulinux.jp/ubuntu-ja-archive-keyring.gpg -O- | apt-key add - && \
    wget -q https://www.ubuntulinux.jp/ubuntu-jp-ppa-keyring.gpg -O- | apt-key add - && \
    wget https://www.ubuntulinux.jp/sources.list.d/bionic.list -O /etc/apt/sources.list.d/ubuntu-ja.list && \
    apt-get update && \
    apt-get install -y apt-cacher-ng

ENTRYPOINT ["/usr/sbin/apt-cacher-ng", "-c", "/etc/apt-cacher-ng", "ForeGround=1"]
