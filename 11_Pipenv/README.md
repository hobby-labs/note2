# Pipenv

```
host$ sudo rm -rf rootfs/root
host$ docker run --rm --name pipenv --hostname pipenv --env LANG=C.UTF-8 --volume ${PWD}/rootfs/root:/root -ti ubuntu:24.04 bash
```

```
pipenv$ cd ~
pipenv$ APT_CACHE_SERVER="172.31.0.11"
pipenv$ cat << EOF > /etc/apt/apt.conf.d/01proxy
Acquire::HTTP::Proxy "http://${APT_CACHE_SERVER}:3142";
Acquire::HTTPS::Proxy "false";
EOF

pipenv$ apt-get update
pipenv$ DEBIAN_FRONTEND=noninteractive apt-get -y install curl git build-essential zlib1g-dev libssl-dev liblzma-dev libsqlite3-dev libreadline-dev libffi-dev libbz2-dev
pipenv$ ln -s /usr/lib/apt/methods/gzip /usr/lib/apt/methods/bzip2

pipenv$ curl https://pyenv.run | bash
```

```
pipenv$ cat << 'EOF' > .bashrc
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
EOF
```

```
pipenv$ bash
pipenv$ pyenv install -l | grep -P ' +([0-9]+\.){2}[0-9]+$'

pipenv$ export LDFLAGS="-L/opt/local/lib"
pipenv$ export CPPFLAGS="-I/opt/local/include"
pipenv$ pyenv install 3.12.5
pipenv$ pyenv global 3.12.5

pipenv$ python --version
> Python 3.12.5
```

# Installing pipenv

```
pipenv$ python -m pip install pipenv --root-user-action ignore
pipenv$ bash
```

# Create a new project
Creating a new project that is using Python 3.12.4.

```
pipenv$ mkdir python-3.12.4
pipenv$ cd python-3.12.4
pipenv$ pipenv --python 3.12.4
```

After run the command, file named "Pipenv" will be created in the current directory.

```
pipenv$ cat Pipfile
> [[source]]
> url = "https://pypi.org/simple"
> verify_ssl = true
> name = "pypi"
> 
> [packages]
> 
> [dev-packages]
> 
> [requires]
> python_version = "3.12"
> python_full_version = "3.12.4"
```

```
pipenv$ pipenv install Faker
pipenv$ cat Pipfile
> [[source]]
> url = "https://pypi.org/simple"
> verify_ssl = true
> name = "pypi"
> 
> [packages]
> faker = "*"
> 
> [dev-packages]
> 
> [requires]
> python_version = "3.12"
> python_full_version = "3.12.4"
```

Creating a sample code.

```
pipenv$ cat << 'EOF' > main.py
import sys
from faker import Faker
print("A version of Python is \"" + sys.version + "\"")
print("--------------------------------------")
fake = Faker()
print(fake.name())
EOF
```

Add a section named '[scripts]' into the Pipfile to run the sample code with prepared Python environment.

```
cat << 'EOF' >> Pipfile
[scripts]
main = "python main.py"
EOF
```

Then run the sample code.

```
pipenv$ python --version
pipenv$ pipenv run main
> A version of Python is "3.12.4 (main, Aug 24 2024, 06:56:59) [GCC 13.2.0]"
> --------------------------------------
> Veronica Underwood
```

Default Python version is `3.12.5`, but when run the code with pipenv, it will run on the Python `3.12.4` that installed by pipenv and written in the Pipfile.

