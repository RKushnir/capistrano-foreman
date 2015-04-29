namespace :foreman do
  desc "Prints the Foreman version on the target host"
  task :check do
    on roles(fetch(:foreman_roles, :all)) do
      if fetch(:log_level) == :debug
        puts capture(:foreman, "version")
      end
    end
  end

  desc "Prefix commands to run them with the ENV-variables loaded"
  task :hook do
    foreman_prefix = "foreman run"
    fetch(:foreman_map_bins).each do |command|
      SSHKit.config.command_map.prefix[command.to_sym].unshift(foreman_prefix)
    end
  end

  desc "Export the Procfile to Ubuntu's upstart scripts"
  task :export do
    on roles(fetch(:foreman_roles, :all)) do
      user = fetch(:foreman_user) { capture(:whoami) }
      as :root do
        execute :foreman,
          "export",
          "upstart",
          "/etc/init",
          "-a", fetch(:application),
          "-u", user,
          "-l", shared_path.join("log"),
          "-e", shared_path.join(".env"),
          "-f", release_path.join("Procfile"),
          "-d", release_path
        end
      end
  end

  desc "Start the application services"
  task :start do
    on roles(fetch(:foreman_roles, :all)) do
      as :root do
        execute :start, fetch(:application)
      end
    end
  end

  desc "Stop the application services"
  task :stop do
    on roles(fetch(:foreman_roles, :all)) do
      as :root do
        execute :stop, fetch(:application)
      end
    end
  end

  desc "Restart the application services"
  task :restart do
    on roles(fetch(:foreman_roles, :all)) do
      as :root do
        status  = capture(:status, fetch(:application))
        command = status =~ /running/ ? :restart : :start
        execute command, fetch(:application)
      end
    end
  end
end

Capistrano::DSL.stages.each do |stage|
  after stage, 'foreman:hook'
  after stage, 'foreman:check'
end

before 'deploy:publishing', 'foreman:export'

namespace :load do
  task :defaults do
    set :foreman_map_bins, %w{rake}
  end
end
