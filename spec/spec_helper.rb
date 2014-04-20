require 'rspec'
require 'redis'
require 'sidekiq'
require_relative '../lib/services'
require_relative 'support/test_services'

support_dir = Pathname.new(File.expand_path('../support', __FILE__))
log_dir     = support_dir.join('logs')

redis_port    = 6379
redis_pidfile = support_dir.join('redis.pid')
redis_url     = "redis://localhost:#{redis_port}/0"

sidekiq_pidfile = support_dir.join('sidekiq.pid')
sidekiq_timeout = 60

Services.configure do |config|
  config.redis   = Redis.new
  config.log_dir = log_dir
end

Sidekiq.configure_client do |config|
  config.redis = { redis: redis_url, namespace: 'sidekiq', size: 1 }
end

Sidekiq.configure_server do |config|
  config.redis = { redis: redis_url, namespace: 'sidekiq' }
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'

  config.before :all do
    # Start Redis
    redis_options = {
      daemonize:  'yes',
      port:       redis_port,
      dir:        support_dir,
      dbfilename: 'redis.rdb',
      logfile:    log_dir.join('redis.log'),
      pidfile:    redis_pidfile
    }
    redis = support_dir.join('redis-server')
    system "#{redis} #{options_hash_to_string(redis_options)}"

    # Start Sidekiq
    sidekiq_options = {
      concurrency: 1,
      daemon:      true,
      timeout:     sidekiq_timeout,
      verbose:     true,
      require:     __FILE__,
      logfile:     log_dir.join('sidekiq.log'),
      pidfile:     sidekiq_pidfile
    }
    system "bundle exec sidekiq #{options_hash_to_string(sidekiq_options)}"
  end

  config.after :all do
    # Stop Sidekiq
    system "bundle exec sidekiqctl stop #{sidekiq_pidfile} #{sidekiq_timeout}"
    while File.exist?(sidekiq_pidfile)
      puts 'Waiting for Sidekiq to shut down...'
      sleep 1
    end

    # Stop Redis
    redis_cli = support_dir.join('redis-cli')
    system "#{redis_cli} -p #{redis_port} shutdown"
    while File.exist?(redis_pidfile)
      puts 'Waiting for Redis to shut down...'
      sleep 1
    end

    # Truncate log files
    max_len = 1024 * 1024 # 1 MB
    Dir[File.join(log_dir, '*.log')].each do |file|
      File.truncate file, max_len if File.size(file) > max_len
    end
  end
end

def options_hash_to_string(options)
  options.map { |k, v| "--#{k} #{v}" }.join(' ')
end
