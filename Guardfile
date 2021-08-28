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
    REDIS_PORT       = 6379

    def self.options_to_string(options)
      options.map { |k, v| "-#{'-' if k.length > 1}#{k} #{v}" }.join(' ')
    end

    class OnStart
      def call(guard_class, event, *args)
        options = {
          daemonize:  'yes',
          dir:        SPEC_SUPPORT_DIR,
          dbfilename: 'redis.rdb',
          logfile:    REDIS_LOGFILE,
          pidfile:    REDIS_PIDFILE,
          port:       REDIS_PORT
        }
        system "#{REDIS_BIN} #{ServicesGemHelpers.options_to_string options}"

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
        options = {
          p: REDIS_PORT
        }
        system "#{REDIS_CLI} #{ServicesGemHelpers.options_to_string options} shutdown"

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

guard 'rspec', cmd: 'bundle exec appraisal rspec' do
  callback ServicesGemHelpers::OnStart.new, :start_begin
  callback ServicesGemHelpers::OnStop.new,  :stop_begin

  # Specs
  watch(%r(^spec/.+_spec\.rb$))

  # Files
  watch(%r(^lib/(.+)\.rb$)) { "spec/#{_1[1]}_spec.rb" }
end
