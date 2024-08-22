# Install

```
host$ docker run --rm --name pyenv --hostname pyenv -ti ubuntu:24.04 bash
```

```
pyenv$ cd ~
pyenv$ apt-get update
pyenv$ apt-get -y install curl git build-essential zlib1g-dev libssl-dev liblzma-dev libsqlite3-dev libreadline-dev libffi-dev libbz2-dev
pyenv$ ln -s /usr/lib/apt/methods/gzip /usr/lib/apt/methods/bzip2

pyenv$ curl https://pyenv.run | bash
```

```
pyenv$ cat << 'EOF' > .bashrc
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
```

```
pyenv$ bash
```

List available Python versions.

```
pyenv$ pyenv install -l | grep -P ' +([0-9]+\.){2}[0-9]+$'
```

```
pyenv$ export LDFLAGS="-L/opt/local/lib" 
pyenv$ export CPPFLAGS="-I/opt/local/include"
pyenv$ pyenv install 3.12.5
pyenv$ pyenv global 3.12.5

pyenv$ python --version
> Python 3.12.5
```

# pyenv virtualenv

```
pyenv$ pyenv virtualenv 3.12.5 pyvenv-3.12.5
pyenv$ pyenv virtualenvs
>  3.12.5/envs/pyvenv-3.12.5 (created from /home/foo/.pyenv/versions/3.12.5)
>  pyvenv-3.12.5 (created from /home/foo/.pyenv/versions/3.12.5)
pyenv$ pyenv activate pyvenv-3.12.5
```

```
(virtualenv-3.12.5)pyenv$ pip list
> Package Version
> ------- -------
> pip     24.2
```

```
(virtualenv-3.12.5)pyenv$ pip install Faker
(virtualenv-3.12.5)pyenv$ pip list
> Package         Version
> --------------- -----------
> Faker           27.0.0
> pip             24.2
> python-dateutil 2.9.0.post0
> six             1.16.0
```

```
(virtualenv-3.12.5)pyenv$ pyenv deactivate
(virtualenv-3.12.5)pyenv$ pip list
> Package Version
> ------- -------
> pip     24.2
```

-----------------------

## Transfer the virtual environment to another server
We must transfer it to the directory that the user's names are same between the old and new servers.
ex) If you made a pyenv with user root and its home directory is /root, you must make a user root on the new server and its home directory must be /root.  
  

First, you should compress files of pyenv.
```
pyenv$ cd ~
pyenv$ tar -zcf pyenv.tar.gz .pyenv
```

```
host$ docker cp pyenv:/root/pyenv.tar.gz .
```

Run another container to copy pyenv.tar.gz and extract it.
```
host$ docker run --rm --name target-pyenv --hostname target-pyenv -ti ubuntu:24.04 bash
```

Copy pyenv.tar.gz to the container.

```
host$ docker cp pyenv.tar.gz target-pyenv:/root/
```

Extract and install pyenv.tar.gz.

```
target-pyenv$ cd ~
target-pyenv$ tar -zxf pyenv.tar.gz
target-pyenv$ cat << 'EOF' > .bashrc
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF

target-pyenv$ bash

target-pyenv$ python --version
target-pyenv$ pyenv virtualenvs
>  3.12.5/envs/pyvenv-3.12.5 (created from /home/foo/.pyenv/versions/3.12.5)
>  pyvenv-3.12.5 (created from /home/foo/.pyenv/versions/3.12.5)

target-pyenv$ pyenv activate pyvenv-3.12.5
target-pyenv$ pyenv activate pyvenv-3.12.5
(pyvenv-3.12.5)target-pyenv$ pip list
> Package         Version
> --------------- -----------
> Faker           27.4.0
> pip             24.2
> python-dateutil 2.9.0.post0
> six             1.16.0
```

* [pyenv/pyenv(GitHub)](https://github.com/pyenv/pyenv?tab=readme-ov-file#installation)

