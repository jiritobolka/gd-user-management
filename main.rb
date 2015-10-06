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

puts options[:data] + '/config.json'
puts "#{options[:data]}/in/tables/users.csv"

# test use case
manager = UMan.new(options)

CSV.foreach(options[:data] + '/in/tables/users.csv', :headers => true) do |csv|
    
    case csv['action']
        when "DISABLE"
        
            result = manager.deactivate_user(csv['user'],csv['pid'])
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
