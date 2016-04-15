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

CSV.foreach(options[:data] + '/in/tables/users.csv', :headers => true, :encoding => 'utf-8') do |csv|

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
                status << [csv['user'], job_id, job_status, "DISABLE", Time.now.getutc, ""]
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
                        status << [csv['user'], job_id, job_status, "CREATE", Time.now.getutc, "", ""]
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
                            status << [csv['user'], job_id, job_status, "ADD", Time.now.getutc, csv['role'], ""]
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
                        status << [csv['user'], job_id, job_status, "ENABLE", Time.now.getutc, csv['role'], ""]
                    end

            end

            if (csv['muf'].to_s != '') then
             # set user filter
             muf_arr = csv['muf']
             muf_user = []

             JSON.parse(muf_arr).each { |x|
             muf_name = x['attribute'] + '_' + csv['user'] + '_' + Time.now.getutc.to_s
             x.store("name", muf_name)
             muf = x.to_json

             result = manager.create_muf(muf,@writer_id)
             muf_user.push(result[0])

             job = result[1]
             job_uri = JSON.parse(job)["url"]
             headers  = {:x_storageapi_token => ENV["KBC_TOKEN"], :accept => :json, :content_type => :json}

             finished = ''
             until finished == 'success'
               res = RestClient.get job_uri, headers
               finished  = JSON.parse(res)["status"]
             end
             }

             muf_user = muf_user.to_json
             result = manager.assign_muf(muf_user, csv['user'], @writer_id)
             puts 'MUF assigned'

             job = result
             job_uri = JSON.parse(job)["url"]
             headers  = {:x_storageapi_token => ENV["KBC_TOKEN"], :accept => :json, :content_type => :json}

             finished = ''
             until finished == 'success'
               res = RestClient.get job_uri, headers
               finished  = JSON.parse(res)["status"]
             end

             CSV.open($out_file.to_s, "ab") do |status|
                 status << [csv['user'], job_id, job_status, "MUF_ASSIGNED", Time.now.getutc, csv['role'], csv['muf']]
             end

          end

        else
            puts "ERROR: no action specified for #{csv['user']}"
            exit 1
    end

end

puts 'User provisioning finished.'

if ($set_variables == 'true') then

    puts "I'm setting variable now..."

    variable_file = options[:data] + '/in/tables/variables.csv'
    success = false

  until success
    begin
          manager.set_existing_variable_bulk(variable_file,$gd_pid)

          rescue Exception => msg

                       message = msg.to_s.split('(')[1].split(',')[0].split('"')[1]
                       puts "oh,shit! Someone is not in the project! Will added later."

                       manager.clean_csv(variable_file,message)
                       #manager.set_existing_variable_bulk(variable_file,$gd_pid)
                       #puts message

          else
                       success = true
    end
  end

    #CSV.foreach(options[:data] + '/in/tables/variables.csv', :headers => true) do |row|
    #if row['user'] == csv['user']
    #        then
    #            manager.set_existing_variable(csv['pid'], row['variable'], row['values'], row['user'])
    #        end
    #end

end

exit 0
