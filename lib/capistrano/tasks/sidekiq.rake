namespace :load do
  task :defaults do
    set :sidekiq_default_hooks, -> { true }

    set :sidekiq_release_path, -> { release_path }
    set :sidekiq_shared_path, -> { shared_path }
    set :sidekiq_pid, -> { File.join(fetch(:sidekiq_shared_path), 'tmp', 'pids', 'sidekiq.pid') }
    set :sidekiq_role, -> { :app }
    set :sidekiq_processes, -> { 1 }
    set :sidekiq_user, -> { nil }
    set :sidekiq_docker_compose_file_path, -> { '/etc/docker/sidekiq/docker-compose.yml' }
    set :sidekiq_docker_env_options, -> { nil }
    set :sidekiq_docker_container_name, -> { nil }
    set :sidekiq_docker_image_name, -> { :sidekiq }
    # Bundler options
    set :sidekiq_bundle_gemfile, -> { release_path.join('Gemfile') }
    set :sidekiq_bundle_without, %w{development test}.join(' ')
    set :sidekiq_bundle_flags, '--deployment --quiet'
  end
end

namespace :deploy do
  before :starting, :check_sidekiq_hooks do
    invoke 'sidekiq:add_default_hooks' if fetch(:sidekiq_default_hooks)
  end
  after :publishing, :restart_sidekiq do
    invoke 'sidekiq:restart' if fetch(:sidekiq_default_hooks)
  end
end

namespace :sidekiq do
  def for_each_process(reverse = false, &block)
    pids = processes_pids
    pids.reverse! if reverse
    pids.each_with_index do |pid_file, idx|
      within fetch(:sidekiq_release_path) do
        yield(pid_file, idx)
      end
    end
  end

  def processes_pids
    pids = []
    sidekiq_roles = Array(fetch(:sidekiq_role))
    sidekiq_roles.each do |role|
      next unless host.roles.include?(role)
      processes = fetch(:"#{ role }_processes") || fetch(:sidekiq_processes)
      processes.times do |idx|
        pids.push fetch(:sidekiq_pid).gsub(/\.pid$/, "-#{idx}.pid")
      end
    end

    pids
  end

  def pid_process_exists?(pid_file)
    pid_file_exists?(pid_file) and test(*("docker exec -i #{fetch(:sidekiq_docker_container_name)} kill -0 $( cat #{pid_file} )").split(' '))
  end

  def pid_file_exists?(pid_file)
    test(*("[ -f #{pid_file} ]").split(' '))
  end

  def stop_sidekiq(pid_file)
    execute "docker exec -i #{fetch(:sidekiq_docker_container_name)} kill -TERM `cat #{pid_file}`"
  end

  def quiet_sidekiq(pid_file)
    execute "docker exec -i #{fetch(:sidekiq_docker_container_name)} kill -USR1 `cat #{pid_file}`"
  end

  def start_sidekiq
    execute "#{fetch(:sidekiq_docker_env_options)} docker-compose -f #{fetch(:sidekiq_docker_compose_file_path)} up -d"
  end

  def restart_sidekiq
    execute "#{fetch(:sidekiq_docker_env_options)} docker-compose -f #{fetch(:sidekiq_docker_compose_file_path)} restart #{fetch(:sidekiq_docker_image_name)}"
  end

  task :add_default_hooks do
    after 'deploy:starting', 'sidekiq:quiet'
    before 'deploy:updated', 'sidekiq:bundle'
    after 'deploy:updated', 'sidekiq:stop'
    after 'deploy:reverted', 'sidekiq:stop'
    after 'deploy:published', 'sidekiq:start'
  end

  desc 'Quiet sidekiq (stop processing new tasks)'
  task :quiet do
    on roles fetch(:sidekiq_role) do |role|
      switch_user(role) do
        if test("[ -d #{fetch(:sidekiq_release_path)} ]") # fixes #11
          for_each_process(true) do |pid_file, idx|
            if pid_process_exists?(pid_file)
              quiet_sidekiq(pid_file)
            end
          end
        end
      end
    end
  end

  desc 'Bundle install'
  task :bundle do
    on roles fetch(:sidekiq_role) do |role|
      switch_user(role) do
        if test("[ -d #{fetch(:sidekiq_release_path)} ]")
          execute "#{fetch(:sidekiq_docker_env_options)} docker-compose -f #{fetch(:sidekiq_docker_compose_file_path)} run #{fetch(:sidekiq_docker_image_name)} bundle install --gemfile #{fetch(:sidekiq_bundle_gemfile)} --without #{fetch(:sidekiq_bundle_without)} #{fetch(:sidekiq_bundle_flags)}"
        end
      end
    end
  end

  desc 'Stop sidekiq'
  task :stop do
    on roles fetch(:sidekiq_role) do |role|
      switch_user(role) do
        if test("[ -d #{fetch(:sidekiq_release_path)} ]")
          for_each_process(true) do |pid_file, idx|
            if pid_process_exists?(pid_file)
              stop_sidekiq(pid_file)
            end
          end
        end
      end
    end
  end

  desc 'Start sidekiq'
  task :start do
    on roles fetch(:sidekiq_role) do |role|
      switch_user(role) do
        start_sidekiq
      end
    end
  end

  desc 'Restart sidekiq'
  task :restart do
    on roles fetch(:sidekiq_role) do |role|
      switch_user(role) do
        restart_sidekiq
      end
    end
  end

  desc 'Rolling-restart sidekiq'
  task :rolling_restart do
    on roles fetch(:sidekiq_role) do |role|
      switch_user(role) do
        restart_sidekiq
      end
    end
  end

  # Delete any pid file not in use
  task :cleanup do
    on roles fetch(:sidekiq_role) do |role|
      switch_user(role) do
        for_each_process do |pid_file, idx|
          if pid_process_exists?(pid_file)
            execute "rm #{pid_file}" unless pid_process_exists?(pid_file)
          end
        end
      end
    end
  end

  def switch_user(role, &block)
    su_user = sidekiq_user(role)
    if su_user == role.user
      block.call
    else
      as su_user do
        block.call
      end
    end
  end

  def sidekiq_user(role)
    properties = role.properties
    properties.fetch(:sidekiq_user) ||               # local property for sidekiq only
    fetch(:sidekiq_user) ||
    properties.fetch(:run_as) || # global property across multiple capistrano gems
    role.user
  end
end
