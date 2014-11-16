module Services
  class Base
    module CallLogger
      def call(*args)
        return super if Services.configuration.logger.nil?

        log "START with args: #{args}", caller: caller
        start = Time.now
        begin
          result = super
        rescue => e
          log exception_message(e), {}, 'error'
          raise e
        ensure
          log 'END', duration: (Time.now - start).round(2)
          result
        end
      end

      private

      def log(message, meta = {}, severity = 'info')
        Services.configuration.logger.log message, meta.merge(service: self.class.to_s, id: @id), severity
      end

      def exception_message(e)
        message = "#{e.class}: #{e.message}"
        e.backtrace.each do |line|
          message << "\n  #{line}"
        end
        message << "\ncaused by: #{exception_message(e.cause)}" if e.respond_to?(:cause) && e.cause
        message
      end

      def caller
        caller_location = caller_locations(1, 10).detect do |location|
          location.path !~ /\A#{Regexp.escape File.expand_path('../..', __FILE__)}/
        end
        if caller_location.nil?
          nil
        else
          caller_path = caller_location.path
          caller_path = caller_path.sub(%r(\A#{Regexp.escape Rails.root.to_s}/), '') if defined?(Rails)
          [caller_path, caller_location.lineno].join(':')
        end
      end
    end
  end
end
