# Main controller of the application.
class MainController < Sinatra::Base
    get '/user' do
        uid = params[:uid]
        return {:uid => uid}.to_json
    end
end
