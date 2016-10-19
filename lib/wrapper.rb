require 'rest-client'
require 'csv'
require 'optparse'
require 'yaml'
require 'json'
require 'time'
require 'securerandom'
require 'gooddata'
require 'fileutils'

class UMan

    def initialize(options)

        @api_endpoint = 'https://syrup.keboola.com/gooddata-writer'
        @config = JSON.parse(File.read(options[:data] + '/config.json'))

        @writer_id = @config["parameters"]["gd_writer"]
        @out_bucket = @config["parameters"]["outputbucket"]
        $set_variables = @config["parameters"]["setvariables"]
        $simple_way = @config["parameters"]["simple_way"]
        $gd_pid = @config["parameters"]["pid"]
        $gd_username = @config["parameters"]["gd_username"]
        $gd_password = @config["parameters"]["#gd_password"]
        @kbc_api_token = ENV["KBC_TOKEN"]

        #$out_file = options[:data] + '/out/tables/' + @out_bucket + '.status.csv'
        $out_file = options[:data] + '/out/tables/' + 'status.csv'

        CSV.open($out_file.to_s, "ab") do |status|
            status << ["user", "job_id", "status", "action_done", "timestamp", "role", "muf"]
        end

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
    def create_user(user,pass,firstname,lastname,sso_provider)

        #   test_user = 'jiri.tobolka+kbc@bizztreat.com'
        #   pass = 'akbvgdrz77'
        #   firstname = 'J'
        #   lastname = 'T'

        values   = "{\"writerId\": \"#{@writer_id}\", \"email\": \"#{user}\", \"password\": \"#{pass}\", \"firstName\": \"#{firstname}\", \"lastName\": \"#{lastname}\", \"ssoProvider\": \"#{sso_provider}\"}"

        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}

        begin
              response = RestClient.post "#{@api_endpoint}/users", values, headers

              rescue Exception => msg

                           puts msg
                           #manager.clean_csv(variable_file,message)
                           #manager.set_existing_variable_bulk(variable_file,$gd_pid)
                           #puts message
                end

        return response

    end

    # does the post on projects/pid/users resource if not available sends invitation
    def add_to_project(user, role, pid)

        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}

        values   = "{ \"writerId\": \"#{@writer_id}\", \"pid\": \"#{pid}\", \"email\": \"#{user}\", \"role\": \"#{role}\" }"

        response = RestClient.post "#{@api_endpoint}/project-users", values, headers

        return response

    end

    # DEPRECATED deactivate user in GoodData project
    def deactivate_user_old(uid, pid)

        #user_id = "f6059d2cd367193ac21f1af2b639a78f"

        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}

        query =     "/gdc/projects/#{pid}/users"

        payload = "{\"user\": { \"content\": { \"status\": \"DISABLED\", \"userRoles\": [ \"/gdc/projects/#{pid}/roles/2\" ]}, \"links\": {\"self\": \"/gdc/account/profile/#{uid}\"}}}"

        values = "{\n \"writerId\": \"#{@writer_id}\",\n \"query\": \"#{query}\",\n \"payload\": #{payload}\n}"

        response = RestClient.post "#{@api_endpoint}/proxy", values, headers

        return response

    end

    # deactivate user using built in KBC feature on API
    def deactivate_user(user, pid)

        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}

        resource = ("#{@api_endpoint}/project-users?writerId=#{@writer_id}&pid=#{pid}&email=#{user}")

        resource.gsub!("+", "%2B")

        response = RestClient.delete resource, headers

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

    # method to assign user values for existing variables (using GoodData Ruby Automation SDK)
    def set_existing_variable_dev(project, var_title, var_values, user)

        # assign to username
        username = $gd_username
        password = $gd_password

        $client = GoodData.connect(username, password)

        project = $client.projects(project)

        var = project.variables.find { |v| v.title == var_title}

        var_attr = var.content['attribute']

        attribute = project.attributes(var_attr)

        label = attribute.primary_label

        values = var_values.split(",")

        filters = []

        filters.push([user, label] + values)

        puts filters

        project.add_variable_permissions(filters, var)

        GoodData.disconnect

    end

    def create_muf(muf, writer_id)
        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}

        response = RestClient.post "https://syrup.keboola.com/gooddata-writer/v2/#{@writer_id}/filters-proxy", muf, headers

        return response
    end

    def assign_muf(mufs, user, writer_id)

        headers  = {:x_storageapi_token => @kbc_api_token, :accept => :json, :content_type => :json}

        response = RestClient.put "https://syrup.keboola.com/gooddata-writer/v2/#{@writer_id}/filters-proxy/#{user}", mufs, headers

        return response
    end

    def clean_csv(file,user)

      csv = CSV.read(file, :encoding => 'utf-8', :headers => :first_row, :return_headers => true)

      csv.by_row!
      csv.delete_if do |row|
          !row.header_row? && row.field('user') == user
      end

      CSV.open("temp.csv","wb") do |csv_out|
          csv.by_row!
          csv.each{ |row| csv_out << row }
      end

      FileUtils.mv("temp.csv", file, :force => true)

    end

    def set_existing_variable_bulk(csv, project)

        # assign to username
        username = $gd_username
        password = $gd_password

        $client = GoodData.connect(username, password)

        project = $client.projects(project)

        array = []

        CSV.foreach(csv, :headers => true, :encoding => 'utf-8') do |row|

            array << row['variable']

            array.uniq

        end

        array.each do |vrr|

            var = project.variables.find { |v| v.title == vrr}

            var_attr = var.content['attribute']

            attribute = project.attributes(var_attr)

            label = attribute.primary_label

            filters = []


            CSV.foreach(csv, :headers => true, :encoding => 'utf-8') do |row|
                if row['variable'] == vrr
                    then

                    values = row['values'].split(",")

                    filters.push([row['user'], label] + values)

                end
            end

            project.add_variable_permissions(filters, var)

        end

        GoodData.disconnect

    end

    def invite_users(csv, project)

      gooddata = []

      # assign to username
      username = $gd_username
      password = $gd_password

      $client = GoodData.connect(username, password)
      project = $client.projects(project)

      gooddata_users = project.users.map {|u| [u.login]}

      CSV.foreach(csv, :headers => true, :encoding => 'utf-8') do |row|

          if !project.member?(row['user'])

                puts "Inviting the user to project..."
                email = row['user']
                role = row['role']

                project.invite(email, role)

              end
      end

      GoodData.disconnect

    end

    def disable_what_is_not_input(csv, project)

      username = $gd_username
      password = $gd_password

      $client = GoodData.connect(username, password)
      project = $client.projects(project)

      gooddata_users = project.users.map {|u| [u.login]}

      input = CSV.read(csv, :headers=>true, :encoding => 'utf-8')['user']

      gooddata_users.each { |usr|
         if !input.to_s.include? usr[0]
           then

            if !usr.to_s.include? 'keboola.com' then
              if !usr.to_s.include? 'gooddata.com' then

                  user_to_disable = project.member(usr[0])
                  user_to_disable.disable
                  puts "User #{usr[0]} has been disabled."

                end
              end
           end
      }

      GoodData.disconnect

    end

end
