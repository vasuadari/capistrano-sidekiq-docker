# Capistrano-sidekiq-docker

Added capistrano support to deploy sidekiq on the docker containers.

## Requirements

1. Capistrano >= 3.0
2. Setup your container using docker-compose

## Installation

    gem 'capistrano-sidekiq-docker', group: :development

And then execute:

    $ bundle


## Usage
```ruby
# Capfile
require 'capistrano/sidekiq'
```


Configurable options:

```ruby
set :sidekiq_release_path, -> { nil }
set :sidekiq_shared_path, -> { nil }
set :sidekiq_pid, -> { File.join(fetch(:sidekiq_shared_path) || fetch(:shared_path), 'tmp', 'pids', 'sidekiq.pid') }
set :sidekiq_role, -> { :app }
set :sidekiq_processes, -> { 1 }
set :sidekiq_user, -> { nil }
set :sidekiq_docker_compose_file_path, -> { '/etc/docker/sidekiq/docker-compose.yml' }
set :sidekiq_docker_env_options, -> { nil }
set :sidekiq_docker_container_name, -> { nil }
set :sidekiq_docker_image_name, -> { 'sidekiq' }
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
