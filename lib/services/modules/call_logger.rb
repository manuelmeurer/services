module Services
  class Base
    module CallLogger
      def call(*args)
        log "START with args #{args}"
        log "CALLED BY #{caller}"
        start = Time.now
        begin
          result = super
        rescue StandardError => e
          log_exception e
          raise e
        ensure
          log "END after #{(Time.now - start).round(2)} seconds"
          result
        end
      end

      private

      def log(message, severity = :info)
        @logger ||= Logger.new
        @logger.log [self.class, @id], message, severity
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
        caller_location = caller_locations(2, 1).first
        caller_path = caller_location.path
        caller_path = caller_path.sub(%r(\A#{Regexp.escape Rails.root.to_s}/), '') if defined?(Rails)
        [caller_path, caller_location.lineno].join(':')
      end
    end
  end
end
