require_relative "../support/docker_rails_app_creator"
require_relative "../support/initialize_project"


namespace :docker do 
  
  desc "Build docker image of this project"
  task :install => :environment do 
    initializer = InitializeProject.new
    initializer.create_configuration()
  end
  
end
