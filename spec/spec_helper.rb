require 'rspec'
require 'tries'
require 'redis'
require 'sidekiq'
require 'timecop'
require 'active_support/core_ext'

require_relative '../lib/services'

PROJECT_ROOT       = Pathname.new(File.expand_path('../..', __FILE__))
TEST_SERVICES_PATH = Pathname.new(File.join('spec', 'support', 'test_services.rb'))
support_dir        = Pathname.new(File.expand_path('../support', __FILE__))
log_dir            = support_dir.join('log')

CALL_PROXY_SOURCE      = support_dir.join('call_proxy.rb')
CALL_PROXY_DESTINATION = PROJECT_ROOT.join('lib', 'services', 'call_proxy.rb')
WAIT                   = 0.5
START_TIMEOUT          = 5
STOP_TIMEOUT           = 20

Dir[support_dir.join('**', '*.rb')].each { |f| require f }

redis_port    = 6379
redis_pidfile = support_dir.join('redis.pid')
redis_url     = "redis://localhost:#{redis_port}/0"

sidekiq_pidfile = support_dir.join('sidekiq.pid')
sidekiq_timeout = 20

Services.configure do |config|
  config.redis  = Redis.new
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

  config.before :suite do
    unless ENV['TRAVIS']
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
    end

    # Start Sidekiq
    sidekiq_options = {
      concurrency: 10,
      daemon:      true,
      timeout:     sidekiq_timeout,
      verbose:     true,
      require:     __FILE__,
      logfile:     log_dir.join('sidekiq.log'),
      pidfile:     sidekiq_pidfile
    }
    system "bundle exec sidekiq #{options_hash_to_string(sidekiq_options)}"

    # Copy call proxy
    FileUtils.cp CALL_PROXY_SOURCE, CALL_PROXY_DESTINATION

    # Wait until Redis and Sidekiq are started
    @processes = {
      'Sidekiq' => sidekiq_pidfile
    }
    @processes['Redis'] = redis_pidfile unless ENV['TRAVIS']
    @processes.each do |process, pidfile|
      i = 0
      while !File.exist?(pidfile)
        puts "Waiting for #{process} to start..."
        sleep WAIT
        i += WAIT
        raise "#{process} didn't start in #{i} seconds." if i >= START_TIMEOUT
      end
    end
  end

  config.after :suite do
    # Delete call proxy
    FileUtils.rm CALL_PROXY_DESTINATION

    # Stop Sidekiq
    system "bundle exec sidekiqctl stop #{sidekiq_pidfile} #{sidekiq_timeout}"

    unless ENV['TRAVIS']
      # Stop Redis
      redis_cli = support_dir.join('redis-cli')
      system "#{redis_cli} -p #{redis_port} shutdown"
    end

    @processes.each do |process, pidfile|
      i = 0
      while File.exist?(pidfile)
        puts "Waiting for #{process} to stop..."
        sleep WAIT
        i += WAIT
        raise "#{process} didn't stop in #{i} seconds." if i >= STOP_TIMEOUT
      end
    end

    # Truncate log files
    max_len = 1024 * 1024 # 1 MB
    Dir[File.join(log_dir, '*.log')].each do |file|
      File.truncate file, max_len if File.size(file) > max_len
    end
  end

  config.after :each do
    wait_for_all_jobs_to_finish
  end
end

def options_hash_to_string(options)
  options.map { |k, v| "--#{k} #{v}" }.join(' ')
end
