require 'sinatra'
require_relative "./config/environment"

# To use request.body.read in a controller
use Rack::RewindableInput::Middleware
# Parse JSON from the request body into the params hash
use Rack::JSONBodyParser
# Starts the server
run MainController
