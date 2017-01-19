
class DockerRailsConfigReader
  attr_accessor :definitions
  
  def initialize
    @definitions = nil
    config_file = "#{FileUtils.pwd}/docker/docker-rails.json"
    raise "Could not find your project config at: #{config_file} .  Did you run: 'rake docker:install' ?" if (!File.exist?(config_file))
    File.open(config_file, "r") do |file|
      str = file.read
      @definitions = JSON.parse(str)
    end
  end
  
  def rails_app_configuration
    @definitions.each do |definition|
      name = definition.keys.first
      if (name == "rails_app")
        return definition
      end
    end
    return nil
  end
  
  
end