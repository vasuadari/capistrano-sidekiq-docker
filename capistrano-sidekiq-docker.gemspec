# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/sidekiq/docker/version'

Gem::Specification.new do |spec|
  spec.name = 'capistrano-sidekiq-docker'
  spec.version = Capistrano::Sidekiq::Docker::VERSION
  spec.authors = ['Vasu Adari']
  spec.email = ['vasuakeel@gmail.com']
  spec.summary = %q{Capistrano support to deploy sidekiq on docker}
  spec.description = %q{Deploy sidekiq on docker}
  spec.homepage = 'https://github.com/vasuadari/capistrano-sidekiq-docker'
  spec.license = 'LGPL-3.0'

  spec.required_ruby_version     = '>= 1.9.3'
  spec.files = `git ls-files`.split($/)
  spec.require_paths = ['lib']

  spec.add_dependency 'capistrano', '>= 3.0'
  spec.add_dependency 'sidekiq', '>= 3.4'
end
