require_relative "./docker_runner"
require_relative "./docker_registry"

class DockerImageCreator
  attr_accessor :use_date_as_version
  
  REMOVE_INTERMEDIATE_FLAG = "--rm=true"
  DAEMON_OPTIONS = " -d -t -P"
  INTERACT_OPTIONS = " -a stdin -a stdout -i -t -P"
  DOCKER_DIR = Dir.pwd + "/lib"
  
  attr_accessor :version_forced, :image_name_forced, :docker_host, :docker_host_secure
  attr_reader :definition

  def initialize(definition)
    raise "Definition is nil" if definition == nil
    @definition = definition
    @home = FileUtils.pwd
    @version = nil
    @docker_host = nil
    @docker_host_secure = nil
  end

  def use_date_as_version?
    false
  end
  
  def image_name
    return (@image_name_forced) if (@image_name_forced)
    build_def = @definition[:build]
    name = @definition[:run][:image_name] if (@definition[:run])
    name = build_def[:name] if (build_def)
    return name
  end 
  
  def docker_api
    @docker_host = @docker_host || ENV['DOCKER_HOST']
    @docker_host_secure = @docker_host_secure || (ENV['DOCKER_TLS_VERIFY'].to_s == '1')
    raise "Need to define DOCKER_HOST env variable" if (!@docker_host)
    raise "Need to define DOCKER_TLS_VERIFY env variable" if (@docker_host_secure == nil)
    docker_api = DockerApi.new(@docker_host, @docker_host_secure)
  end
  
  def build_it()
    docker_connection = docker_api.connection
    build_def = @definition[:build]
    if (build_def == nil)
      puts "Warning: build not defined for #{definition[:code]} - ignoring request"
    else
      begin
        before_build(@definition)
        remove_intermediate = REMOVE_INTERMEDIATE_FLAG
    
        volume_path = build_def[:volume_path]
        build_command = nil
      
        image_and_version = image_name()
        image_and_version += ":#{version()}" if (version() != nil)

        opts = build_def[:api_options] || {}
        opts[:t] = "#{image_and_version}"
        opts[:rm] = true

        Excon.defaults[:write_timeout] = 1000
        Excon.defaults[:read_timeout] = 1000
        puts "Building image.  Docker dir: #{docker_dir} ..."
        
        image = Docker::Image.build_from_dir(docker_dir, opts, docker_connection) do |v|
          begin
            if (log = JSON.parse(v)) && log.has_key?("stream")
              $stdout.puts log["stream"]
            end
          rescue Exception => ex
            puts "#{v}"
          end
        end
      rescue Exception => ex
        puts"Exception: #{ex.message}"
        puts ex.backtrace
        debugger
        raise "Exception building image.  #{ex.message}\nCheck connection to: #{docker_connection}"
      ensure
        after_build(@definition)
      end
    end
  end

  def version
    return (@version_forced) if (@version_forced)
    build_def = @definition[:build]
    raise "No build definition for: #{@definition[:code]}" if (!build_def)
    version = 'latest'
    version = build_def[:version] if (build_def[:version] != nil)
    return version
  end

  def tag_it(registry)
    raise "DOCKER_REGISTRY environment variable not defined for push operation" if registry == nil
    do_tag(registry)
  end
  
  #def do_tag(image_name, version, registry)
  def do_tag(registry)
    docker_connection = docker_api.connection
    image = Docker::Image.get("#{image_name}:#{version}", {}, docker_connection)
    puts "Tagging image: #{image_name}"
    image.tag('repo' => "#{registry}/#{image_name()}", 'image' => 'unicorn', 'tag' => version(), force: true)
  end
  
  def push_it(registry)
    raise "DOCKER_REGISTRY environment variable not defined for push operation" if registry == nil
    build_def = @definition[:build]
    do_push(registry)
  end
  
  def api_image(registry, docker_connection)
    full_name = "#{registry}/#{image_name}"
    full_name += ":#{version()}" if (version() != nil)
    image = Docker::Image.get(full_name, {}, docker_connection)
    puts "Pushing Image: #{full_name} ..."
    return image
  end
  
  def do_push(registry)
    if (registry)
      Excon.defaults[:write_timeout] = 1000
      Excon.defaults[:read_timeout] = 1000
    
      docker_connection = docker_api.connection
  
      image = api_image(registry, docker_connection)

      credentials = nil
      result = image.push(credentials, {tag: version, repo: registry}) 
      puts "Done pushing Image: #{registry}/#{image_name}"
      the_registry = DockerRegistry.new(registry)
      
      if (the_registry.has_image_with_version?("#{image_name}", version) == false) 
        raise "After push, image doesn't appear in registry.  Image: #{image_name}:#{version}.  Push result: #{result}"
      end
    else
      puts "No registry specified for pushing"
    end
  end
  
  def run_it(host, host_ssl, interact, run_instance_count, registry = nil)
    @docker_host = host
    @docker_host_secure = host_ssl
    puts "Warning:  registry not defined, assuming run is local" if registry == nil
    run_def = @definition[:run]
    build_def = @definition[:build]
    if (run_def == nil)
      puts "No run definition for: #{@definition[:code]}" 
    else
      (1..run_instance_count).each do |instance_index|
        use_extension = (run_instance_count > 1)
        run_with_extension(:next, registry, interact, use_extension)
      end
    end
  end
  
  def run_with_extension(instance_index, registry, interact, use_extension)
    @docker_api = DockerApi.new(@docker_host)
    docker_runner = DockerRunner.new(self, nil)
    docker_runner.registry = registry
    docker_runner.instance_index = instance_index
    docker_runner.use_extension = use_extension
    docker_runner.interact =  interact
    docker_runner.image_name = image_name
    docker_runner.code = @definition[:code]
    docker_runner.remote_address = @docker_host
    docker_runner.secure_docker_api = @docker_host_secure
    docker_runner.run_with_extension
  end
  
  def add_it(host, host_ssl, run_instance_count, registry)
    @docker_host = host
    @docker_host_secure = host_ssl
    number_added = 0
    while (number_added < run_instance_count)
      run_def = @definition[:run]
      run_name = run_def[:name]
      extension = 1
      run_with_extension(:next, registry, false, true)
      number_added += 1
    end
  end
  
  def kill_all(host, host_ssl)
    docker_runner = DockerRunner.new(self, nil)
    docker_runner.registry = nil
    docker_runner.use_extension = true
    docker_runner.interact =  false
    docker_runner.remote_address = host
    docker_runner.secure_docker_api = host_ssl

    run_def = @definition[:run]
    run_name = run_def[:name]
    docker_runner.kill_all(run_name)
  end
  
  def subtract(host, host_ssl, count)
    docker_runner = DockerRunner.new(self, nil)
    docker_runner.registry = nil
    docker_runner.use_extension = true
    docker_runner.interact =  false
    docker_runner.remote_address = host
    docker_runner.secure_docker_api = host_ssl

    run_def = @definition[:run]
    run_name = run_def[:name]
    docker_runner.kill(run_name, count)
  end
  
  def openlogic_home()
    @openlogic_home = @openlogic_home[0..(@openlogic_home.length - 2)] if (@openlogic_home.end_with? "/")
    return @openlogic_home
  end

  def before_build(definition)
    delete_image_support_from_stage()
    copy_image_support_to_stage()
  end
  
  def after_build(definition)
    delete_image_support_from_stage()
  end
  
  def delete_image_support_from_stage()
    FileUtils.remove_dir("#{docker_dir}image_support", true)
  end
  
  def docker_dir
    return @definition[:build][:docker_directory] + "/"
  end
  
  def copy_image_support_to_stage
    raise "Definition nil" if @definition == nil
    raise "Build Definition nil" if @definition[:build] == nil
    image_support_dir = "#{FileUtils.pwd}/lib/support/image_support/"
    FileUtils.cp_r(image_support_dir, docker_dir())
  end
  
end
