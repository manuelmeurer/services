require 'rspec'
require 'tries'
require 'redis'
require 'sidekiq'
require 'timecop'
require 'active_support'
require 'active_support/core_ext'

require_relative '../lib/services'

PROJECT_ROOT           = Pathname.new(File.expand_path('../..', __FILE__))
SUPPORT_DIR            = Pathname.new(File.expand_path('../support', __FILE__))
TEST_SERVICES_PATH     = Pathname.new(File.join('spec', 'support', 'test_services.rb'))
CALL_PROXY_DESTINATION = PROJECT_ROOT.join('lib', 'services', 'call_proxy.rb')
CALL_PROXY_SOURCE      = SUPPORT_DIR.join('call_proxy.rb')
SIDEKIQ_PIDFILE        = SUPPORT_DIR.join('sidekiq.pid')
WAIT                   = 0.5
START_TIMEOUT          = 5
SIDEKIQ_TIMEOUT        = 20

Dir[SUPPORT_DIR.join('**', '*.rb')].each { |f| require f }


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
      timeout:     SIDEKIQ_TIMEOUT,
      verbose:     true,
      require:     __FILE__,
      logfile:     SUPPORT_DIR.join('log', 'sidekiq.log'),
      pidfile:     SIDEKIQ_PIDFILE
    }
    system "bundle exec sidekiq #{options_hash_to_string(sidekiq_options)}"

    # Copy call proxy
    FileUtils.cp CALL_PROXY_SOURCE, CALL_PROXY_DESTINATION

    # Wait for Sidekiq to start
    i = 0
    while !File.exist?(SIDEKIQ_PIDFILE)
      puts 'Waiting for Sidekiq to start...'
      sleep WAIT
      i += WAIT
      raise "Sidekiq didn't start in #{i} seconds." if i >= START_TIMEOUT
    end
  end

  config.after :suite do
    # Stop Sidekiq
    system "bundle exec sidekiqctl stop #{SIDEKIQ_PIDFILE} #{SIDEKIQ_TIMEOUT}"

    # Delete call proxy
    FileUtils.rm CALL_PROXY_DESTINATION

    i = 0
    while File.exist?(SIDEKIQ_PIDFILE)
      puts 'Waiting for Sidekiq to stop...'
      sleep WAIT
      i += WAIT
      raise "Sidekiq didn't stop in #{i} seconds." if i >= SIDEKIQ_TIMEOUT + 1
    end
  end

  config.after :each do
    wait_for_all_jobs_to_finish
  end
end

def options_hash_to_string(options)
  options.map { |k, v| "--#{k} #{v}" }.join(' ')
end
