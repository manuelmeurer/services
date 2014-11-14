module Services
  class Base
    module CallLogger
      def call(*args)
        return super if Services.configuration.logger.nil?

        log "START with args #{args}"
        log "CALLED BY #{caller || '(not found)'}"
        start = Time.now
        begin
          result = super
        rescue => e
          log_exception e
          raise e
        ensure
          log "END after #{(Time.now - start).round(2)} seconds"
          result
        end
      end

      private

      def log(message, severity = :info)
        Services.configuration.logger.log message, [self.class, @id], severity
      end

      def log_exception(e, cause = false)
        log "#{'caused by: ' if cause}#{e.class}: #{e.message}"
        if e.respond_to?(:cause) && e.cause
          e.backtrace.take(5).each do |line|
            log "  #{line}"
          end
          log_exception(e.cause, true)
        else
          e.backtrace.each do |line|
            log "  #{line}"
          end
        end
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
