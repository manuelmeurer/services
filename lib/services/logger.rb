require 'active_support/tagged_logging'

module Services
  class Logger
    def initialize
      unless Services.configuration.log_dir.nil?
        log_file = File.join(Services.configuration.log_dir, 'services.log')
        @logger = ActiveSupport::TaggedLogging.new(::Logger.new(log_file))
        @logger.clear_tags!
      end
    end

    def log(tags, message, severity = :info)
      unless @logger.nil?
        @logger.tagged Time.now, severity.upcase, *tags do
          @logger.send severity, message
        end
      end
    end
  end
end
