# Install

```
mkdir -p rootfs/{root,opt}
docker run --rm --name pyenv --hostname pyenv \
    --volume ${PWD}/rootfs/root:/root \
    --volume ${PWD}/rootfs/opt:/opt \
    -ti ubuntu:24.04 bash
```

```
apt-get update
apt-get -y install curl git build-essential zlib1g-dev libssl-dev liblzma-dev libsqlite3-dev libreadline-dev libffi-dev libbz2-dev
ln -s /usr/lib/apt/methods/gzip /usr/lib/apt/methods/bzip2
curl https://pyenv.run | bash
```

```
cat << 'EOF' > .bashrc
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
```

```
bash
```

List available Python versions.

```
pyenv install -l | grep -P ' +([0-9]+\.){2}[0-9]+$'
```

```
export LDFLAGS="-L/opt/local/lib" 
export CPPFLAGS="-I/opt/local/include"
pyenv install 3.12.5
pyenv global 3.12.5
```



* [pyenv/pyenv(GitHub)](https://github.com/pyenv/pyenv?tab=readme-ov-file#installation)

