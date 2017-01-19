require 'docker_rails_app'
require 'rails'

spec = Gem::Specification.find_by_name 'docker-rails-app'

Dir.glob("#{spec.gem_dir}/lib/tasks/**/*.rake").each { |file|
  load file
}

