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

CALL_PROXY_SOURCE      = support_dir.join('call_proxy.rb')
CALL_PROXY_DESTINATION = PROJECT_ROOT.join('lib', 'services', 'call_proxy.rb')
WAIT                   = 0.5
START_TIMEOUT          = 5
STOP_TIMEOUT           = 20

Dir[support_dir.join('**', '*.rb')].each { |f| require f }

sidekiq_pidfile = support_dir.join('sidekiq.pid')
sidekiq_timeout = 20

Services.configure do |config|
  config.redis = Redis.new
end

Sidekiq.configure_client do |config|
  config.redis = { redis: 'redis://localhost:6379/0', namespace: 'sidekiq', size: 1 }
end

Sidekiq.configure_server do |config|
  config.redis = { redis: 'redis://localhost:6379/0', namespace: 'sidekiq' }
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'

  config.before :suite do
    # Start Sidekiq
    sidekiq_options = {
      concurrency: 10,
      daemon:      true,
      timeout:     sidekiq_timeout,
      verbose:     true,
      require:     __FILE__,
      logfile:     support_dir.join('log', 'sidekiq.log'),
      pidfile:     sidekiq_pidfile
    }
    system "bundle exec sidekiq #{options_hash_to_string(sidekiq_options)}"

    # Copy call proxy
    FileUtils.cp CALL_PROXY_SOURCE, CALL_PROXY_DESTINATION

    # Wait for Sidekiq to start
    i = 0
    while !File.exist?(sidekiq_pidfile)
      puts 'Waiting for Sidekiq to start...'
      sleep WAIT
      i += WAIT
      raise "Sidekiq didn't start in #{i} seconds." if i >= START_TIMEOUT
    end
  end

  config.after :suite do
    # Stop Sidekiq
    system "bundle exec sidekiqctl stop #{sidekiq_pidfile} #{sidekiq_timeout}"

    # Delete call proxy
    FileUtils.rm CALL_PROXY_DESTINATION

    i = 0
    while File.exist?(sidekiq_pidfile)
      puts 'Waiting for Sidekiq to stop...'
      sleep WAIT
      i += WAIT
      raise "Sidekiq didn't stop in #{i} seconds." if i >= STOP_TIMEOUT
    end
  end

  config.after :each do
    wait_for_all_jobs_to_finish
  end
end

def options_hash_to_string(options)
  options.map { |k, v| "--#{k} #{v}" }.join(' ')
end
