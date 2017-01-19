require_relative "../support/docker_rails_app_creator"

namespace :docker do 

  desc "Run Docker image"
  task :run => :environment do 
    config_reader = DockerRailsConfigReader.new
    config_reader.definitions.each do |definition|
      definition_name = definition.keys.first
      definition_value = definition[definition_name]
      if (definition_value['run'])
        docker_runner = DockerRunner.new(definition_value)
        docker_runner.docker_host = "tcp://127.0.0.1:2375"
        docker_runner.docker_host_secure = true
        docker_runner.run
      end
    end
  end
  

  desc "Run Local Docker image"
  task :run_local => :environment do 
    config_reader = DockerRailsConfigReader.new
    config_reader.definitions.each do |definition|
      definition_name = definition.keys.first
      definition_value = definition[definition_name]
      if (definition_value['run'])
        docker_runner = DockerRunner.new(definition_value)
        docker_runner.docker_host = "tcp://127.0.0.1:2375"
        docker_runner.docker_host_secure = true
        docker_runner.run_untagged = true
        docker_runner.run
      end
    end
  end

  
end
