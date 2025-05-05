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
