require 'fileutils'

class InitializeProject
  def app_docker_path
    project_dir = FileUtils.pwd
    docker_dir = "#{project_dir}/docker"
    FileUtils.mkdir_p("#{docker_dir}/files")
    return docker_dir
  end
  
  def fill_in_file_param(file_path, param_name, param_value)
    new_content = nil
    File.open(file_path, "r") do |file|
      content = file.read
      search_str = "<<#{param_name}>>"
      index = content.index(search_str)
      content_start = content[0..(index - 1)]
      content_end = content[(index + search_str.length), content.length]
      new_content = content_start + param_value + content_end
    end
    File.open(file_path, "w") do |file|
      file.write(new_content)
    end
  end

  def create_configuration
    #Use directory name as default for image name.
    default_image_name = FileUtils.pwd.split('/').last
    default_image_name = default_image_name.split('_').join("-")
    default_image_name = default_image_name.split(' ').join("-")
    
    puts "Creating configurations."
    puts "Enter image name of rails app (#{default_image_name}):"
    image_name = STDIN.gets.chomp
    if (image_name.length == 0)
      image_name = default_image_name
    end
    
    db_run_time_name = image_name + "-db"
    
    docker_dir = app_docker_path()
    FileUtils.mkdir_p("#{docker_dir}/files")
    
    this_dir = File.dirname(__FILE__)
    docker_file_path = "#{docker_dir}/Dockerfile"
    copy_docker_file = true
    if (File.exist?(docker_file_path))
      puts "Dockerfile already exists in #{docker_dir}.  Overwrite? (y/n)"
      overwrite = STDIN.gets.chomp
      if (overwrite.downcase == "n")
        copy_docker_file = false
      end
    end
    
    if (copy_docker_file)
      FileUtils.cp("#{this_dir}/image_files/DockerfileSelf", docker_file_path)
      fill_in_file_param(docker_file_path, 'SQL_HOST', db_run_time_name)
      puts "Copied standard Dockerfile to: #{docker_dir}"
    end
    
    
    copy_entry_file = true
    entry_file_path = "#{docker_dir}/entrypoint.sh"
    if (File.exist?(entry_file_path))
      puts "Entrypoint.sh already exists in #{docker_dir}.  Overwrite? (y/n)"
      overwrite = STDIN.gets.chomp
      if (overwrite.downcase == "n")
        copy_entry_file = false
      end
    end
    
    if (copy_entry_file)
      FileUtils.cp("#{this_dir}/image_files/entrypoint.sh", "#{docker_dir}/entrypoint.sh")
      puts "Copied entry point file to: #{docker_dir}"
    end

    FileUtils.cp("#{this_dir}/image_files/wait_for_port.sh", "#{docker_dir}/wait_for_port.sh")
    
    
    main_configuration = {
      registry: "https://my.registry.com:5000",
      build: {
        name: image_name
      },
      run: {
        name: image_name,
        options: {
          "Env" => [
            "IS_DOCKER=true"
          ],
          "HostConfig" => {
            "Links" => ["#{db_run_time_name}:#{db_run_time_name}"],
            "PortBindings" => {
              "3000/tcp" => [
                      {"HostIp" => "", "HostPort" => "3000"}
              ]
            }
          }
        }
      }
    }
    
    sql_configuration = {
      run: {
        name: db_run_time_name,
        image_name: "percona:5.6",
        options: {
          "Env" => [
            "MYSQL_ROOT_PASSWORD=password"
          ],
          "HostConfig" => {
            "PortBindings" => {
              "3306/tcp" => []
            }
          }
        }
      }
    }
    
    
    configs = [{sql: sql_configuration}, {rails_app: main_configuration}]
    
    output = JSON.pretty_generate(configs)
    config_file_path = "#{app_docker_path}/docker-rails.json"
    File.open(config_file_path, "w") do |f|
      f.write(output)
    end
    
  end

end