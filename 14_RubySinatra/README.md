# Install RVM

```
$ curl -L get.rvm.io > rvm-install
$ bash < ./rvm-install
$ # For zsh
$ source ~/.zshrc
```

```
$ rvm install 3.3.6
$ rvm use 3.3.6 --default
```


```
$ mkdir sinatra_app
$ cd sinatra_app
$ bundle init
$ bundle add sinatra rake rerun puma
$ cat Gemfile
> # frozen_string_literal: true
> 
> source "https://rubygems.org"
> 
> # gem "rails"
> 
> gem "sinatra", "~> 4.1"
> gem "rackup", "~> 2.2"
> gem "rerun", "~> 0.14.0"
> gem "puma", "~> 6.5"

$ bundle install --path .bundle
```

