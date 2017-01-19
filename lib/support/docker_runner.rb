require_relative "launch_support"
require_relative "./docker_api"
require 'pp'

class DockerRunner
  include LaunchSupport
  attr_accessor :instance_index, :registry, :use_extension, :interact, :image_name, :code
  attr_accessor :host, :user, :deployment_id, :version, :secure_docker_api, :remote_address
  attr_accessor :docker_host, :docker_host_secure, :run_untagged
  

  def initialize(config)
    @config = config
    @run_config = config['run']
    @build_config = config['build']
    @run_untagged = false
    
    @image_name = @run_config['image_name']
    if (!@image_name) 
      if (@build_config)
        @image_name = @build_config['name']
        raise "Build config does not have 'name'" if (@image_name == nil)
      else
        raise "Can't find an image name.  Either specify 'name' in build config or 'image_name' in run config."
      end
    end
    
    @registry = @config['registry'] 
    
    @instance_index = 0
    @use_extension = false
    @interact = false
    @remote_address = nil
    @api_container = nil
    @version = nil
    @secure_docker_api = true
    @build_args = nil
  end
  
  def find_machine_apis
    @run_on_apis = []
    @all_docker_apis_in_cluster = []
    if (@deploy_config != nil) && (@deploy_config[:hosts] != nil)
      @deploy_config[:hosts].each do |host_key|
        host = Hosts::HOSTS[host_key]
        address = "tcp://#{host[:address]}:#{host[:docker_port]}"
        docker_api = DockerApi.new(address, host[:ssl])
        @all_docker_apis_in_cluster << docker_api
        @run_on_apis << docker_api if (address == @remote_address) || ( @deploy_config[:targets][run_name] == :all)
      end
    else
      # Config not given, we need to create api from remote address and ssl setting.  This is the only api for this class.
      @docker_host = @docker_host || ENV['DOCKER_HOST']
      @docker_host_secure = @docker_host_secure || (ENV['DOCKER_TLS_VERIFY'].to_s == '1')
      docker_api = DockerApi.new(@docker_host, @docker_host_secure)
      
      @all_docker_apis_in_cluster << docker_api
      @run_on_apis << docker_api
    end
  end
  
  def run_name
    return @run_config['name']
  end
  
  def image_version
    return @version if (@version != nil)
    the_version = 'latest'
    the_version = @build_config['version'] if (@build_config) && (@build_config['version'] != nil)
    return the_version
  end
  
  def kill_all(name_prefix)
    find_machine_apis
    @all_docker_apis_in_cluster.each do |api|
      #options = {filters: {status: [:running, :exited, :paused, :restarting]}}
      options = {}
      containers = Docker::Container.all(options.to_json, api.connection)
      containers.each do |container|
        if (container.json["Name"].start_with?("/#{name_prefix}"))
          pp "Killing and removing: #{container.json["Name"]}"
          container.kill() if (container.json["State"]["Running"])
          container.remove() if (container != nil)
        else
          pp " * Container didn't match: #{container.json["Name"]}"
        end
      end
    end
  end
  
  
  def run
    find_machine_apis
    raise "No run on apis" if (@run_on_apis.count == 0)

    code = @code
    instance_index = 1
    if (@instance_index == :next)
      options = {filters: {status: [:running]}}
      @active_container_names = []
      containers = Docker::Container.all(options.to_json, @run_on_apis.first.connection)
      containers.each do |container|
        container_json = container.json
        container_name = container_json["Name"]
        @active_container_names << container_name
      end
      
      instance_index = 1
      container_name_taken = true
      while (true)
        instance_ext = "_#{instance_index}"
        instance_name = "/#{run_name}#{instance_ext}"
        if (!@active_container_names.include? instance_name)
          @instance_index = instance_index
          break
        else
          instance_index += 1
        end
      end
    end
    
    instance_ext = ""
    instance_ext = "_#{@instance_index}" if (@use_extension)
    instance_name = "#{run_name}#{instance_ext}"

    @all_docker_apis_in_cluster.each do |docker_api|
      kill_previous_containers_in_cluster(docker_api, instance_name)
    end
    image_name = image_name_with_registry()

    @run_on_apis.each do |docker_api|
      if (!@run_untagged)
        pull_image_to_host(docker_api, registry)
      end
      run_container(docker_api, instance_name)
    end
  end
  
  
  private

  def pull_image_to_host(docker_api, registry)
    return if (registry == nil)  || (@run_untagged)
    Excon.defaults[:write_timeout] = 500
    Excon.defaults[:read_timeout] = 500
    options = {}
    options[:repo] = registry
    options[:fromImage] = "#{image_name_with_registry}:#{image_version}"
    pp "See if Host needs to pull image (#{options[:fromImage]}).  Host: #{docker_api.connection}"
    
    image = Docker::Image.create(options, nil, docker_api.connection)
  end  

  def run_container(docker_api, instance_name)
    create_options = @run_config['options'] || {}

    if (!image_name_with_registry.include? ":")
      create_options['Image'] = "#{image_name_with_registry}:#{image_version}" 
    else
      create_options['Image'] = image_name_with_registry 
    end
    create_options['name'] = instance_name
    create_options['Labels'] = { deployer: @user, deploy_id: @deployment_id }
    create_options['Tty'] = true if (@interact == true)
    create_options['Entrypoint'] = ["/bin/bash"] if (@interact == true)
      
    pp "Running container: #{instance_name}\nOptions: #{create_options}"
    cli_command = "docker run --name #{instance_name}"
    if (create_options['Env'] != nil)
      create_options['Env'].each do |env|
        cli_command += " -e #{env}"
      end
    end
    if (create_options['HostConfig'] != nil)
      host_config = create_options['HostConfig']
      binds = host_config['Binds']
      if (binds != nil) 
        binds.each do |bind|
          cli_command += " -v #{bind}"
        end
      end
      links = host_config['Links']
      if (links != nil)
        links.each do |link|
          cli_command += " --link #{link}"
        end
      end
      ports = host_config['PortBindings']
      ports.keys.each do |port|
        container_port = port.split("/").first
        host_port = container_port
        port_binds = ports[port]
        port_binds.each do |bind|
          host_port = bind['HostPort']  if (bind['HostPort'] != nil)
          cli_command += " -p #{host_port}:#{container_port}"
        end
        if (port_binds.length == 0)
          cli_command += " -p #{host_port}:#{container_port}"
        end
      end
    end
    cli_command += " -d"
    cli_command += " #{create_options['Image']}"
    cli_command += " #{create_options['Entrypoint']}" if (create_options['Entrypoint'] != nil)
    puts "CLI Command: #{cli_command}"
    
    @api_container = Docker::Container.create(create_options, docker_api.connection)
    puts @api_container.start
    if (@interact)
      pp "=================================================================="
      pp "CONTAINER STARTED FOR INTERACTION - ENTRYPOINT NOT CALLED"
      pp "To attach:  docker exec -it '#{instance_name}' bash"
      pp "=================================================================="
    end
  end

  
  def kill_previous_containers_in_cluster(docker_api, instance_name)
    pp "Killing and removing containers with same name: #{instance_name}"
    @api_container = nil
    begin
      @api_container = Docker::Container.get(instance_name, {}, docker_api.connection)
      puts "Killing and removing container: #{instance_name} in #{docker_api.connection}"
      @api_container.kill()
    rescue Docker::Error::NotFoundError => not_found_error
      puts "No container with name \"#{instance_name}\" running.  No need to kill."    
    end
    
    if (@api_container)
      begin
        pp "Removing container: #{instance_name}"
        @api_container.remove() if (@api_container != nil)
      rescue Docker::Error::NotFoundError => remove_error
        puts "Didn't find image to remove: #{instance_name}"
      end
    end
  end


  def image_name_with_registry
    image_name = @image_name
    if (registry != nil) && (!@run_untagged)
      registry_without_protocol = registry.split("://").last
      image_name = "#{registry_without_protocol}/#{@image_name}"
    end
    return image_name
  end

  def container_state
    return @api_container.json['State']
  end

  def wait_for_completion 
    while (container_state()["Running"] == true)
      sleep 1
      puts "Waiting for container #{run_name} to finish."
    end
    exit_code = container_state()['ExitCode']
    raise "Container failed (#{image_name_with_registry()}) Exit code: #{exit_code}" if (exit_code != 0) 
  end

  
end