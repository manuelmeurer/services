module Services
  class Base
    module CallLogger
      def call(*args)
        log "START with args: #{args}"
        start = Time.now
        begin
          result = super
        rescue StandardError => e
          log "#{e.class}: #{e.message}"
          e.backtrace.each do |line|
            log line
          end
          raise e
        ensure
          log "END after #{(Time.now - start).round(2)} seconds"
          result
        end
      end
    end
  end
end
