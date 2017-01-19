require_relative "../support/docker_rails_config_reader"
require_relative "../support/docker_rails_app_creator"


namespace :docker do 

  
  desc "Build docker image of this project"
  task :build => :environment do 
    config_reader = DockerRailsConfigReader.new
    config_reader.definitions.each do |definition|
      definition_name = definition.keys.first
      definition_value = definition[definition_name]
      if (definition_value['build'])
        builder = DockerRailsAppCreator.new(definition_value)
        builder.docker_host = "tcp://127.0.0.1:2375"
        builder.docker_host_secure = true
        builder.build_it
      end
    end
  end

  desc "Push docker image to repo"
  task :push => :environment do 
    config_reader = DockerRailsConfigReader.new
    config_reader.definitions.each do |definition|
      definition_name = definition.keys.first
      definition_value = definition[definition_name]
      if (definition_value['build'])
        builder = DockerRailsAppCreator.new(definition_value)
        builder.docker_host = "tcp://127.0.0.1:2375"
        builder.docker_host_secure = true
        registry = definition_value['registry']
        if (registry)
          builder.tag_it(registry)
          builder.push_it(registry)
        else
          puts "No registry definited.  Ignoring push command."
        end
      end
    end
  end
  
  
end
