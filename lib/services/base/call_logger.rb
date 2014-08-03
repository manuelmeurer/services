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
          if e.respond_to?(:cause) && !e.cause.nil?
            log "caused by: #{e.cause.class}: #{e.cause.message}"
            e.cause.backtrace.each do |line|
              log line
            end
          else
            e.backtrace.each do |line|
              log line
            end
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
