require 'guard/rspec'

module ::Guard
  class RSpec < Plugin
    # Add `stop` method if not defined
    # so that `stop_*` callbacks work.
    unless instance_methods.include?(:stop)
      def stop; end
    end
  end

  module ServicesGemHelpers
    SPEC_SUPPORT_DIR = Pathname.new(File.expand_path('../spec/support', __FILE__))
    REDIS_BIN        = SPEC_SUPPORT_DIR.join('redis-server')
    REDIS_CLI        = SPEC_SUPPORT_DIR.join('redis-cli')
    REDIS_PIDFILE    = SPEC_SUPPORT_DIR.join('redis.pid')
    REDIS_LOGFILE    = SPEC_SUPPORT_DIR.join('log', 'redis.log')

    class OnStart
      def call(guard_class, event, *args)
        redis_options = {
          daemonize:  'yes',
          dir:        SPEC_SUPPORT_DIR,
          dbfilename: 'redis.rdb',
          logfile:    REDIS_LOGFILE,
          pidfile:    REDIS_PIDFILE,
        }
        system "#{REDIS_BIN} #{redis_options.map { |k, v| "--#{k} #{v}" }.join(' ')}"

        i = 0
        while !File.exist?(REDIS_PIDFILE)
          puts 'Waiting for Redis to start...'
          sleep 1
          i += 1
          raise "Redis didn't start in #{i} seconds." if i >= 5
        end
      end
    end

    class OnStop
      def call(guard_class, event, *args)
        system "#{REDIS_CLI} shutdown"

        i = 0
        while File.exist?(REDIS_PIDFILE)
          puts 'Waiting for Redis to stop...'
          sleep 1
          i += 1
          raise "Redis didn't stop in #{i} seconds." if i >= 5
        end
      end
    end
  end
end

guard 'rspec', cmd: 'bundle exec rspec' do
  callback ServicesGemHelpers::OnStart.new, :start_begin
  callback ServicesGemHelpers::OnStop.new,  :stop_begin

  # Specs
  watch(%r(^spec/.+_spec\.rb$))
  watch('spec/spec_helper.rb')       { 'spec' }
  watch(%r(^spec/support/(.+)\.rb$)) { 'spec' }

  # Files
  watch(%r(^lib/(.+)\.rb$))          { |m| "spec/#{m[1]}_spec.rb" }
end
