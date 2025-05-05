require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require './app/controllers/main_controller.rb'

RSpec.describe 'app' do
    let(:app) { MainController.new(nil, logger, ldap, ad_ldap, user, admin, group) }

    context "When the request reached to the endpoint GET /user" do
        it 'should call :get_by_uid_from_ldap with argument "taro" if GET parameter is "uid=taro"' do
            expected_response = [
                                    {:dn => "uid=taro-suzuki,ou=Users,dc=mysite,dc=example,dc=com",:cn => "taro-suzuki"}
                                ]

            allow(logger).to receive(:info).with("Searching a user on the endpoint GET /user/?uid=taro, ENV['LDAP_HOST']: 127.0.0.1")
            allow(user).to receive(:get_by_uid_from_ldap).with("taro").and_return(expected_response)

            get '/user', uid: "taro"    # HTTP GET with parameter "uid=taro"
            expect(last_response.status).to eq 200
            expect(last_response.body).to eq(expected_response.to_json)
        end

        it 'should call :get_by_uid_from_ldap with argument nil if GET parameter is not specified' do
            expected_response = [
                                    {:dn => "uid=taro-suzuki,ou=Users,dc=mysite,dc=example,dc=com",:cn => "taro-suzuki"},
                                    {:dn => "uid=hanako-tanaka,ou=Users,dc=mysite,dc=example,dc=com",:cn => "hanako-tanaka"}
                                ]

            allow(logger).to receive(:info).with("Searching a user on the endpoint GET /user/?uid=, ENV['LDAP_HOST']: 127.0.0.1")
            allow(user).to receive(:get_by_uid_from_ldap).with(nil).and_return(expected_response)

            get '/user'    # HTTP GET without any parameters
            expect(last_response.status).to eq 200
            expect(last_response.body).to eq(expected_response.to_json)
        end
    end

end
