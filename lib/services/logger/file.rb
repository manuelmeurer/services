require 'active_support/tagged_logging'

module Services
  module Logger
    class File
      def initialize(log_dir)
        log_file = ::File.join(log_dir, 'services.log')
        @logger = ActiveSupport::TaggedLogging.new(::Logger.new(log_file))
        @logger.clear_tags!
      end

      def log(message, meta = {}, severity = 'info')
        tags = meta.map do |k, v|
          [k, v].join('=')
        end
        @logger.tagged Time.now, severity.upcase, *tags do
          @logger.public_send severity, message
        end
      end
    end
  end
end
