# Setup Gems
gem 'bootstrap-sass', '~> 3.2.0'
gem 'autoprefixer-rails'
gem "font-awesome-rails"
gem 'underscore-rails'
gem 'rubyzip'
gem 'rack-cache'
gem 'dalli'
gem 'kgio'
gem "memcachier"
gem 'protected_attributes'
gem 'rails_12factor'
gem 'haml-rails'
gem 'therubyracer'

if yes?('Run advanced setup (config_files, scaffold generation, model generation, controller generation, gem additions, rake tasks, database migrations)? (yes | no)')
  # TODO: should probably ask them up front what advanced options they want to run so they don't have to go through all the questions

  if yes?('Do you need to add additional Gems? (yes | no)')
    num_gems = ask('How many additional Gems do you want to add?').to_i
    num_gems.times do |num|
      gem_name = ask('What is the name of the gem you want to add?')
      # TODO: Should ask if we want to pin a gem to a version
      # TODO: Should probably ask if we need to run any generators after gem addition
      if yes?('Does this gem need to go into any Gem Groups? (yes | no)')
        if yes?('Does this Gem need to be in the Production Gem Group? (yes | no)')
          gem_group :production do
            gem "#{gem_name}"
          end
        elsif yes?('Does this Gem need to be in the Test Gem Group? (yes | no)')
          gem_group :test do
            gem "#{gem_name}"
          end
        elsif yes?('Does this Gem need to be in the Development / Test Gem Group? (yes | no)')
          gem_group :development, :test do
            gem "#{gem_name}"
          end
        else
          gem "#{gem_name}"
        end
      else
        gem "#{gem_name}"
      end
    end
  end

  if yes?('Do you need to add any config files? (yes | no)')
    num_configs = ask('How many config files do you want to add?').to_i
    num_configs.times do |num|
      config_file_name = ask('What is the name for the config file?')
      file "config/#{config_file_name}"
      file "config/#{config_file_name}.example"
      if yes?('Do you want to add the config file to the .gitignore? (yes | no)')
        run("echo .gitignore >> config/#{config_file_name}")
      end
    end
  end

  if yes?('Do you need to generate any scaffolds? (yes | no)')
    num_scaffolods = ask('How many scaffolds do you want to generate?').to_i
    num_scaffolods.times do |num|
      scaffold_name = ask('What is the name for this scaffold?')
      # TODO: should probably ask what attributes they want to add to each scaffold
      generate(:scaffold, scaffold_name)
    end
  end

  if yes?('Do you need to generate any controllers? (yes | no)')
    num_controllers = ask('How many controllers do you want to generate?').to_i
    num_controllers.times do |num|
      controller_name = ask('What is the name for this controller?')
      # TODO: should probably ask what attributes they want to add to each controller
      generate(:controller, controller_name)
    end
  end

  if yes?('Do you need to generate any models? (yes | no)')
    num_models = ask('How many models do you want to generate?').to_i
    num_models.times do |num|
      model_name = ask('What is the name for this model?')
      # TODO: should probably ask what attributes they want to add to each model
      generate(:model, model_name)
    end
  end

  if yes?('Do you need to generate any rake tasks? (yes | no)')
    num_tasks = ask('How many rake tasks do you want to generate?').to_i
    num_tasks.times do |num|
      task_namespace = ask('What is the namespace for this rake task?')
      task_name = ask('What is the name for this rake task?')
      generate(:task, "#{task_namespace} #{task_name}")
    end
  end

  if yes?('Do you need to generate any database migrations? (yes | no)')
    num_migrations = ask('How many database migrations do you want to generate?').to_i
    num_migrations.times do |num|
      migration_name = ask('What is the name for this migration?')
      # TODO: should probably ask what attributes they want to add to each migration
      generate(:migration, migration_name)
    end
  end
end

gem_group :development, :test do
  gem 'debugger'
  gem 'sqlite3'
  gem 'rspec-rails', '~> 3.0.0.beta'
  gem 'pry'
end

gem_group :test do
  gem 'shoulda-matchers'
  gem 'webmock'
  gem 'simplecov', require: false
  gem 'factory_girl_rails'
end

gem_group :production do
  gem 'pg'
  gem 'unicorn'
  gem 'heroku-deflater'
end

run("echo ruby \\'2.0.0\\' >>  'Gemfile'")

# Setup Unicorn
file 'Procfile', <<-CODE
web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
CODE

file 'config/unicorn.rb', <<-CODE
worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)
timeout 15
preload_app true

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
CODE

# Bundle And Migrations
  # TODO: support rvm, chruby ect...
run('rbenv install 2.0.0-p247')
run('rbenv local 2.0.0-p247')
run("bundle install")
rake("db:migrate")

# Remove Test folder
run('rm -rf test')

# Generate RSpec stuff
run('rails generate rspec:install')

# Remove Sqlite3 from main part of Gemfile
open('Gemfile-new', 'w') do |output|
  open('Gemfile', 'r') do |input|
    input.each_line do |line|
      output.write(line) if line.strip !=  "gem 'sqlite3'"
    end
  end
end

#Add Cache Control
open('config/application-new.rb', 'w') do |output|
  open('config/application.rb', 'r') do |input|
    input.each_line do |line|
      output.write(line)
      output.write("    config.cache_store = :dalli_store \n") if line.strip == "class Application < Rails::Application"
    end
  end
end

# Remove old Gemfile
run('rm Gemfile')

# Move new Gemfile
run('mv Gemfile-new Gemfile')

# Remove Production.rb
run('rm config/environments/production.rb')

# Add New Produciton.rb
file 'config/environments/production.rb', <<-CODE
#{@app_name.capitalize}::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  client = Dalli::Client.new((ENV["MEMCACHIER_SERVERS"] || "").split(","),
                             :username => ENV["MEMCACHIER_USERNAME"],
                             :password => ENV["MEMCACHIER_PASSWORD"],
                             :failover => true,
                             :socket_timeout => 1.5,
                             :socket_failure_delay => 0.2,
                             :value_max_bytes => 10485760)
  config.action_dispatch.rack_cache = {
    :metastore    => client,
    :entitystore  => client
  }
  config.static_cache_control = "public, max-age=2592000"

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Disable Rails's static asset server (Apache or nginx will already do this).
  config.serve_static_assets = true

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = true

  # Generate digests for assets URLs.
  config.assets.digest = true

  # Version of your assets, change this if you want to expire all your assets.
  config.assets.version = '1.0'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Set to :debug to see everything in the log.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
  # config.assets.precompile += %w( search.js )

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new
end
CODE

# Initial commit
git :init
git add: "."
git commit: %Q{ -m 'Initial commit'}

github_clone_url = ask('Github Clone URL (example: git@github.com:cottonwoodcoding/cottonwood-coding.git):')
run("git remote add github #{github_clone_url}")

# Push to Gerrit
git push: "github master"

# Add Remotes
if yes?('Add additional Git remotes? (yes | no)')
  number_to_add = ask('How many?')
  to_add = number_to_add.to_i
  if to_add > 0
    to_add.to_i.times do |num|
      remote_name = ask("Remote #{num + 1} name:")
      remote_url = ask("#{remote_name} url:")
      if remote_name.empty? || remote_url.empty?
        puts "Remote name and Remote URL have to have values. Skipping"
        next
      end
      run("git remote add #{remote_name} #{remote_url}")
      git push: "#{remote_name} master" if yes?('Push to this remote? (yes | no)')
    end
  else
    puts "Number of remotes to add needs to be greater than 0. Skipping"
  end
end

