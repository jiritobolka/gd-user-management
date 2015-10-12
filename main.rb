require 'rest-client'
require 'csv'
require 'optparse'
require 'yaml'
require 'json'

class UMan
    
    def initialize(options)
        
        @api_endpoint = 'https://syrup.keboola.com/gooddata-writer'
        @config = JSON.parse(File.read(options[:data] + '/config.json'))
        
        @writer_id = @config["parameters"]["gd_writer"]
        @kbc_api_token = ENV["KBC_TOKEN"]
        
    end
    
    # get users from GoodData Project
    def get_users
        
        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}
        
        response = RestClient.get "#{@api_endpoint}/users?writerId=#{@writer_id}", headers
        
        return response
        
    end
    
    # get role IDs for specific project
    def get_project_roles(pid)
        
        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}
        
        query = "/gdc/projects/#{pid}/roles"
        
        response = RestClient.get "#{@api_endpoint}/proxy?writerId=#{@writer_id}&query=#{query}", headers
        
        # parse key values for specific project roles
        
        return response
        
    end
    
    #create new user in Keboola Organization
    def create_user(user,pass,firstname,lastname)
        
        #   test_user = 'jiri.tobolka+kbc@bizztreat.com'
        #   pass = 'akbvgdrz77'
        #   firstname = 'J'
        #   lastname = 'T'
        
        values   = "{ \"writerId\": \"#{@writer_id}\", \"email\": \"#{test_user}\", \"password\": \"#{pass}\", \"firstName\": \"#{firstname}\", \"lastName\": \"#{lastname}\"}"
        
        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}
        
        response = RestClient.post "#{@api_endpoint}/users", values, headers
        
        return response
        
    end
    
    # does the post on projects/pid/users resource if not available sends invitation
    def add_to_project(user, role, pid)
        
        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}
        
        values   = "{ \"writerId\": \"#{@writer_id}\", \"pid\": \"#{pid}\", \"email\": \"#{user}\", \"role\": \"#{role}\" }"
        
        response = RestClient.post "#{@api_endpoint}/project-users", values, headers
        
        return response
        
    end
    
    # deactivate user in GoodData project
    def deactivate_user(uid, pid)
        
        #user_id = "f6059d2cd367193ac21f1af2b639a78f"
        
        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}
        
        query =     "/gdc/projects/#{pid}/users"
        
        payload = "{\"user\": { \"content\": { \"status\": \"DISABLED\", \"userRoles\": [ \"/gdc/projects/#{pid}/roles/2\" ]}, \"links\": {\"self\": \"/gdc/account/profile/#{uid}\"}}}"
        
        values = "{\n \"writerId\": \"#{@writer_id}\",\n \"query\": \"#{query}\",\n \"payload\": #{payload}\n}"
        
        response = RestClient.post "#{@api_endpoint}/proxy", values, headers
        
        return response
        
    end
    
    # activate existing user in GoodData project (only for users within your domain)
    def activate_user
        
        #user_id = "f6059d2cd367193ac21f1af2b639a78f"
        
        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}
        
        query = "/gdc/projects/#{pid}/users"
        
        payload = "{\"user\": { \"content\": { \"status\": \"ENABLED\", \"userRoles\": [ \"/gdc/projects/#{pid}/roles/2\" ]}, \"links\": {\"self\": \"/gdc/account/profile/#{uid}\"}}}"
        
        values = "{\n \"writerId\": \"#{@writer_id}\",\n \"query\": \"#{query}\",\n \"payload\": #{payload}\n}"
        
        response = RestClient.post "#{@api_endpoint}/proxy", values, headers
        
        return response
        
    end
    
    # apply changes for users
    def set_users
        
    end
    
    # method for saving result in SAPI (log eventu)
    def save_output
        
    end
    
end


options = {}
OptionParser.new do |opts|
    
    opts.on('-d', '--data DAT', 'Data') { |v| options[:data] = v }
    
end.parse!

if options[:data].nil?
then
    puts 'No data folder is set.'
    exit 1
end

manager = UMan.new(options)

CSV.foreach(options[:data] + '/in/tables/users.csv', :headers => true) do |csv|
    
    case csv['action']
        when "DISABLE"
        
            usrs = JSON.parse(manager.get_users())['users']
            filtered = usrs.select { |u| u['email'] == csv['user'] }
            uid = filtered[0]['uid']
        
            result = manager.deactivate_user(uid,csv['pid'])
            CSV.open(options[:data] + '/out/tables/status.csv', "ab") do |status|
                status << [csv['user'], result]
            end
        
        
        when "ENABLE"
        
            result = manager.add_to_project(csv['user'],csv['role'],csv['pid'])
            CSV.open(options[:data] + '/out/tables/status.csv', "ab") do |status|
                status << [csv['user'], result]
            end
        
        else
            puts "ERROR: no action specified for #{csv['user']}"
            exit 1
    end
    
end

puts 'User provisioning finished.'
exit 0
