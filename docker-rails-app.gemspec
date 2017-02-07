# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'docker_rails_app/version'

Gem::Specification.new do |spec|
  spec.name          = "docker-rails-app"
  spec.version       = DockerRailsApp::VERSION
  spec.authors       = ["Mike Moore"]
  spec.email         = ["m.moore.denver@gmail.com"]

  spec.summary       = "Puts your rails app into a Docker image"
  spec.description   = "Puts your rails app into a Docker image"
  spec.license       = "MIT"

  spec.homepage      = 'https://github.com/mikejmoore/docker-rails-app'

  spec.files = Dir.glob("{bin,lib}/**/*")
  spec.files <<    "lib/docker_rails_app.rb"  
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib", "lib/docker_rails_app"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency 'docker-api', '~> 1.31'
end
