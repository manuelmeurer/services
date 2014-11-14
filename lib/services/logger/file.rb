require 'active_support/tagged_logging'

module Services
  module Logger
    class File
      def initialize(log_dir)
        log_file = ::File.join(log_dir, 'services.log')
        @logger = ActiveSupport::TaggedLogging.new(::Logger.new(log_file))
        @logger.clear_tags!
      end

      def log(message, tags = [], severity = :info)
        @logger.tagged Time.now, severity.upcase, *tags do
          @logger.send severity, message
        end
      end
    end
  end
end
