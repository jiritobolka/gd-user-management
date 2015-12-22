require './lib/wrapper'

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
        
        #usrs = JSON.parse(manager.get_users())['users']
        #   filtered = usrs.select { |u| u['email'] == csv['user'] }
        #   uid = filtered[0]['uid']
        # result = manager.deactivate_user(uid,csv['pid'])
        
            result = manager.deactivate_user(csv['user'],csv['pid'])
            
            job_uri = JSON.parse(result)["url"]
            
            headers  = {:x_storageapi_token => ENV["KBC_TOKEN"], :accept => :json, :content_type => :json}
            
            finished = false
            until finished
                res = RestClient.get job_uri, headers
                finished  = JSON.parse(res)["isFinished"]
            end
            
            job_status = JSON.parse(res)["status"]
            message = JSON.parse(res)["result"][0]
            
            job_id = JSON.parse(result)["job"]
            
            CSV.open($out_file.to_s, "ab") do |status|
                status << [csv['user'], job_id, job_status, message, "DISABLE", Time.now.getutc]
            end
        
        
        when "ENABLE"
        
            if (csv['sso_provider'].to_s != '')
                then
                
                    # create user with sso provider
                    result = manager.create_user(csv['user'], SecureRandom.hex.to_s, csv['firstname'], csv['lastname'], csv['sso_provider'])
                
                    job_uri = JSON.parse(result)["url"]
                
                    headers  = {:x_storageapi_token => ENV["KBC_TOKEN"], :accept => :json, :content_type => :json}
                
                    finished = false
                    until finished
                        res = RestClient.get job_uri, headers
                        finished  = JSON.parse(res)["isFinished"]
                    end
                
                    job_status = JSON.parse(res)["status"]
                    message = JSON.parse(res)["result"][0]
                
                    job_id = JSON.parse(result)["job"]
                    
                    CSV.open($out_file.to_s, "ab") do |status|
                        status << [csv['user'], job_id, job_status, "CREATE", Time.now.getutc]
                    end
                    
                    
                    if job_status != 'error' then
                    
                        # push the new user to the project directly
                        result = manager.add_to_project(csv['user'],csv['role'],csv['pid'])
                    
                        job_uri = JSON.parse(result)["url"]
                    
                        headers  = {:x_storageapi_token => ENV["KBC_TOKEN"], :accept => :json, :content_type => :json}
                    
                        finished = false
                        until finished
                            res = RestClient.get job_uri, headers
                            finished  = JSON.parse(res)["isFinished"]
                        end
                    
                        job_status = JSON.parse(res)["status"]
                        message = JSON.parse(res)["result"][0]
                    
                        job_id = JSON.parse(result)["job"]
                    
                        CSV.open($out_file.to_s, "ab") do |status|
                            status << [csv['user'], job_id, job_status, "ADD", Time.now.getutc]
                        end
                    end

                else
                
                    result = manager.add_to_project(csv['user'],csv['role'],csv['pid'])
            
                    job_uri = JSON.parse(result)["url"]
            
                    headers  = {:x_storageapi_token => ENV["KBC_TOKEN"], :accept => :json, :content_type => :json}
            
                    finished = false
                    until finished
                        res = RestClient.get job_uri, headers
                        finished  = JSON.parse(res)["isFinished"]
                    end
            
                    job_status = JSON.parse(res)["status"]
                    message = JSON.parse(res)["result"][0]
            
                    job_id = JSON.parse(result)["job"]
            
                    CSV.open($out_file.to_s, "ab") do |status|
                        status << [csv['user'], job_id, job_status, "ENABLE", Time.now.getutc]
                    end
            end
        
        else
            puts "ERROR: no action specified for #{csv['user']}"
            exit 1
    end
    
end

puts 'User provisioning finished.'
exit 0
