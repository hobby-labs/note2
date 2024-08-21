# Install

```
docker run --rm --name pyenv --hostname pyenv -ti ubuntu:24.04 bash
```

```
cd ~
apt-get update
apt-get -y install curl git build-essential zlib1g-dev libssl-dev liblzma-dev libsqlite3-dev libreadline-dev libffi-dev libbz2-dev
ln -s /usr/lib/apt/methods/gzip /usr/lib/apt/methods/bzip2

useradd foo -m
su - foo
bash

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

python --version
> Python 3.12.5
```

# pyenv virtualenv

```
pyenv virtualenv 3.12.5 pyvenv-3.12.5
pyenv virtualenvs
>  3.12.5/envs/pyvenv-3.12.5 (created from /home/foo/.pyenv/versions/3.12.5)
>  pyvenv-3.12.5 (created from /home/foo/.pyenv/versions/3.12.5)
pyenv activate pyvenv-3.12.5
```

```
(virtualenv-3.12.5) $ pip list
> Package Version
> ------- -------
> pip     24.2
```

```
(virtualenv-3.12.5) $ pip install Faker
(virtualenv-3.12.5) $ pip list
> Package         Version
> --------------- -----------
> Faker           27.0.0
> pip             24.2
> python-dateutil 2.9.0.post0
> six             1.16.0
```

```
(virtualenv-3.12.5) $ pyenv deactivate
pip list
> Package Version
> ------- -------
> pip     24.2
```

-----------------------

# We must transfer it to the directory that the user's names are same between the old and new servers.

```


* [pyenv/pyenv(GitHub)](https://github.com/pyenv/pyenv?tab=readme-ov-file#installation)

