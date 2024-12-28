# Install RVM

* [RVM](https://wiki.archlinux.org/title/RVM)
* [Andrew-Ochieng/ruby-sinatra-application-structure](https://github.com/Andrew-Ochieng/ruby-sinatra-application-structure)

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
$ bundle add sinatra rake rerun puma rackup require_all sinatra-activerecord rack-contrib pry
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

* config.ru
```ruby
require 'sinatra'
require_relative "./config/environment"

# Parse JSON from the request body into the params hash
use Rack::JSONBodyParser
# Starts the server
run ApplicationController
```

* Rakefile
```
require_relative './config/environment'
require 'sinatra/activerecord/rake'

desc "Runs a Pry console"
task :console do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    Pry.start
end

task :server do
    exec "rerun -b 'rackup config.ru -p 8000'"
end
```

* config/environment.rb
```
# This is an _environment variable_ that is used by some of the Rake tasks to determine
# if our application is running locally in development, in a test environment, or in production
ENV['RACK_ENV'] ||= 'development'

# Require in Gems
require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'])

# Require in all files in 'app' directory
require_all 'app'
```

