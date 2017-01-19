require 'json'

class DockerRegistry

  def initialize(registry_url)
    @server = registry_url
    if (!registry_url.include? "://")
      registry_url = "https://#{registry_url}"
    end
    @connection = connection(registry_url)
  end

  def find_images()
    response = @connection.get "/v2/_catalog"
    raise "catalog retrieval return error: #{response.status} #{response.body}" if (response.status != 200)
    json = JSON.parse(response.body)
    return json['repositories']
  end
  
  def find_tags(image_name)
    response = @connection.get "/v2/#{image_name}/tags/list"
    raise "Querying tags returned error code: #{response.status}" if (response.status != 200)
    json = JSON.parse(response.body)
    return json['tags']
  end
  
  def has_image_with_version?(image, commit_id) 
    tags = self.find_tags(image)
    if (tags != nil)
      tags.each do |tag|
        return true if (tag == commit_id)
      end
    end
    return false
  end
  
  def images_and_versions
    hash = {}
    images = find_images()
    images.each do |image|
      tags = find_tags(image)
      hash[image] = tags
    end
    return hash
  end
  
  private 
  
  def connection(address)
    if (!@service_connection)
      @service_connection = Faraday.new address, :ssl => {:verify => false}
    end
    return @service_connection
  end
  
  

end
