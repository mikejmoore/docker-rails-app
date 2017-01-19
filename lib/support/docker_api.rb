# DOCKER_URL=tcp://qa2:4243 ruby lib/docker-api/docker_api_tests.rb 
# DOCKER_URL=tcp://192.168.99.100:2376 ruby lib/docker-api/docker_api_tests.rb 
require 'docker'

raise "Remove this monkey patch when API library provides this stats method" if (Docker::Container.respond_to? "stats")
class Docker::Container
  # Non streaming stats
  def stats(options = {})
    path = path_for(:stats)
    puts "Getting stats from: #{path}"
    options[:stream] = false
    container_stats = nil
    begin
      status = Timeout::timeout(5) {
        container_stats = connection.get(path, options)
      }
    rescue Exception => e
      return {error: e.message}
    end
    JSON.parse(container_stats)
  end
end

class DockerApi
  attr_accessor :connection
  
  # Build a connection to docker on a remote host.  Need a connection to be able to make multiple docker calls within the app to different hosts.
  # host:   {address: "olex-qa2.openlogic.com", docker_port: 4245 }
  def self.connection(host)
    cert_path = ENV['DOCKER_CERT_PATH']
    scheme = "http"
    scheme = "https" if (ENV['DOCKER_TLS_VERIFY'] == "1")
    
    docker_connection_opts = {:client_cert=>"#{cert_path}/cert.pem", :client_key=>"#{cert_path}/key.pem",
      :ssl_ca_file=>"#{cert_path}/ca.pem", :scheme => scheme}
    
    # docker_connection_opts = {:client_cert=>"/Users/mikemoore/.docker/machine/machines/dev/cert.pem", :client_key=>"/Users/mikemoore/.docker/machine/machines/dev/key.pem",
    #   :ssl_ca_file=>"/Users/mikemoore/.docker/machine/machines/dev/ca.pem", :scheme=>"https"}
    docker_connection_opts[:scheme] = "http" if (host[:ssl] == false)
    docker_connection = Docker::Connection.new("tcp://#{host[:address]}:#{host[:docker_port]}", docker_connection_opts)
    return docker_connection
  end
  
  def initialize(url, secure = true)
    # Docker.logger = Logger.new(STDOUT)
    # Docker.logger.level = Logger::DEBUG
    address = url.split("//").last.split(":").first
    port = url.split(":").last
    host = {address: address, docker_port: port, ssl: secure}
    @connection = DockerApi.connection(host)
  end

  def find_container_with_name(wanted_name)
    options = {
      all: true
    }
    all_containers = Docker::Container.all(options, @connection)
    all_containers.each do |container|
      json = container.json
      name = json['Name']
      return container if (name == "/#{wanted_name}")
    end
    return nil
  end
end


#
# puts ""
# puts "Here are Containers on #{docker_url}"
# all_containers = Docker::Container.all
# all_containers.each do |container|
#   puts "#{container.json['Name']}"
#   puts "   Running: #{container.json['State']['Running']}"
#   puts "   Running: #{container.json['State']['ExitCode']}"
#
#   env_vars = container.json['Config']['Env']
#   env_vars.each do |env|
#     puts "       Env: #{env}"
#   end
# end
