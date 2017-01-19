module LaunchSupport

  def is_port_open?(ip, port)
    begin
      Timeout::timeout(1) do
        begin
          puts "Connecting to #{ip}: #{port}"
          s = TCPSocket.new(ip, port)
          s.close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          return false
        end
      end
    rescue Timeout::Error
    end
    return false
  end


  def wait_for_short_lived_image_to_complete(image_run_name)
    done = false
    while (!done)
      #puts "Inspecting image: #{image_run_name}"
      output = `docker inspect #{image_run_name}`
      #puts "Output: #{output}"
      json = JSON.parse(output)
      state = json.first['State']
      is_running = state['Running']
      exit_code =  state['ExitCode']
      puts "Waiting for short-lived container to complete: \"#{image_run_name}\""
      if (exit_code == 0) && (is_running == false)
        done = true
      elsif (exit_code != 0)
        raise "Container failed: #{image_run_name}  - Run: docker logs -f #{image_run_name}"
      else
        sleep 3
      end
    end
  end

  def wait_for_port(ip, port)
    while (!is_port_open?(ip, port))
      puts "Port not ready: #{ip}:#{port}"
      sleep 3
    end
  end


  def host
    output = `boot2docker ip`
    if (output.strip.length == 0) || (output.include?("command not found")) || (output.include?("is not running"))
      docker_machine_active = `docker-machine active`
      docker_machine_active = docker_machine_active[0..(docker_machine_active.length - 2)]
      output = `docker-machine url #{docker_machine_active}`
      address = output.split("//")[1].split(":").first
      return address
    else
      return output.strip
    end
  end
end