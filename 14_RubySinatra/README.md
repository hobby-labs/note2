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
$ bundle add sinatra rake puma rackup require_all sinatra-activerecord rack-contrib
$ bundle add rerun pry --group development
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

# To use request.body.read in a controller
use Rack::RewindableInput::Middleware
# Parse JSON from the request body into the params hash
use Rack::JSONBodyParser
# Starts the server
run MainController
```

* Rakefile
```
require_relative './config/environment'
require 'sinatra/activerecord/rake'
require 'rspec/core/rake_task'

desc "Runs a Pry console"
task :console do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    Pry.start
end

task :server do
    exec "rerun -b 'rackup config.ru -p 8000'"
end

task :spec do
    ENV['RACK_ENV'] = 'test'
    RSpec::Core::RakeTask.new(:spec)
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

```
$ mkdir -p app/controllers
$ vim app/controllers/main_controller.rb
```

Controller を作成し、GET メソッドのエンドポイントを追加します。

* app/controllers/main_controller.rb
```
# Main controller of the application.
class MainController < Sinatra::Base
    get '/user' do
        uid = params[:uid]
        return {:uid => uid}.to_json
    end
end
```

Server を起動する。

```
$ bundle exec rake server
> ...
> Puma starting in single mode...
> * Puma version: 6.5.0 ("Sky's Version")
> * Ruby version: ruby 3.3.6 (2024-11-05 revision 75015d4c1f) [x86_64-linux]
> *  Min threads: 0
> *  Max threads: 5
> *  Environment: development
> *          PID: 12828
> * Listening on http://127.0.0.1:8000
> * Listening on http://[::1]:8000
> Use Ctrl-C to stop
```

サーバを起動したら、エンドポイントにアクセスし、想定通りの結果が帰ってくることを確認します。

```
$ curl 'http://localhost:8000/user?uid=taro'
> {"uid":"taro"}
```

# Test suite
* [BUNDLE-ADD/ArchLinux](https://man.archlinux.org/man/bundle-add.1.en)

テストライブラリを追加します。
group を指定することで、test 時のみに適用されるようになります。

```
$ bundle add rspec rack-test --group test
```

```
$ bundle exec rspec --init
>  create   .rspec
>  create   spec/spec_helper.rb
```

# RSpec
RSpec を使ってテストを追加します。

まずはhelper を編集します。

```bash
$ mkdir spec/
$ vim spec/spec_helper.rb
```

* spec/spec_helper.rb
```ruby
ENV['APP_ENV'] = 'test'

require 'sinatra'
require 'rspec'
require 'rack/test'
# A line below is required to call static method 'Command::exec' from the test codes.
# https://stackoverflow.com/a/32271976/4307818
require File.expand_path("../../config/environment", __FILE__)

RSpec.configure do |config|
    config.expect_with :rspec do |expectations|
        expectations.include_chain_clauses_in_custom_matcher_descriptions = true
        expectations.max_formatted_output_length = nil
    end

    config.mock_with :rspec do |mocks|
        mocks.verify_partial_doubles = true
    end
    config.shared_context_metadata_behavior = :apply_to_host_groups

    config.include Rack::Test::Methods
    def app
        MainController
    end
end
```

```
$ mkdir -p spec/controllers
$ vim spec/controllers/main_controller_spec.rb
```

