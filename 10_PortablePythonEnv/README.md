# Preparing

```
#docker run --rm --name python3 --hostname pytyon3 --volume ${PWD}:/root -ti python:3.12 bash
docker run --rm --name python3 --hostname pytyon3 --volume ${PWD}:/opt -ti python:3.12 bash
```

These instruction assumes that you will port this environment only among Linux systems.
And you have to create a virtual env in the directory where you will put it on same directory on other Linux systems.
ex) If you create this virtualenv in /opt/myenv on Linux-A, you have to put it on /opt/myenv on Linux-B.

```
cd /opt
python3 -m venv --copies portable_python
source portable_python/bin/activate

(portable_python) #
```

```
(portable_python) # pip install --upgrade pip
(portable_python) # pip install Faker
(portable_python) # cat << 'EOF' > test.py
from faker import Faker
fake = Faker()
print(fake.name())
EOF

(portable_python) # python test.py
> Kristen Reynolds
```

On the host that running the docker container, you can archive a venv directory and copy it to another host.

```
tar -zcf portable_python.tar.gz portable_python
ls portable_python.tar.gz
> portable_python.tar.gz
```

Run another system with docker.

```
docker run --rm --name another --hostname another -ti ubuntu:24.04 bash
```

Copy the portable_python.tar.gz to the another system.

```
docker cp portable_python.tar.gz another:/opt
> Successfully copied x.xMB to another:/opt
```

```
cd /opt/
tar -zxf portable_python.tar.gz

(portable_python) root@another:/opt/portable_python# python test.py
python: error while loading shared libraries: libpython3.12.so.1.0: cannot open shared object file: No such file or directory
```

https://github.com/python/cpython/issues/87500

Can I create a venv by using tarball

* (Is there a single line way to run a command in a Python venv?)[https://stackoverflow.com/questions/48174599/is-there-a-single-line-way-to-run-a-command-in-a-python-venv]
* (How to make venv completely portable?)[https://stackoverflow.com/a/69076225]

 https://www.python.org/ftp/python/3.12.0

