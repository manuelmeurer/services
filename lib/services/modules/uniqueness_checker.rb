module Services
  class Base
    module UniquenessChecker
      KEY_PREFIX = %w(
        services
        uniqueness
      ).join(':')

      ON_ERROR = %i(
        fail
        ignore
        reschedule
      )

      MAX_RETRIES = 10
      ONE_HOUR = 60 * 60

      def self.prepended(mod)
        mod.const_set :NotUniqueError, Class.new(mod::Error)
      end

      def check_uniqueness!(*args, on_error: :fail)
        raise "on_error must be one of #{ON_ERROR.join(', ')}, but was #{on_error}" unless ON_ERROR.include?(on_error.to_sym)
        raise 'Service args not found.' if @service_args.nil?
        @uniqueness_args = args.empty? ? @service_args : args
        new_uniqueness_key = uniqueness_key(@uniqueness_args)
        raise "A uniqueness key with args #{@uniqueness_args.inspect} already exists." if @uniqueness_keys && @uniqueness_keys.include?(new_uniqueness_key)
        if @similar_service_id = Services.configuration.redis.get(new_uniqueness_key)
          case on_error.to_sym
          when :fail
            raise_non_unique_error
          when :reschedule
            if error_count >= MAX_RETRIES
              raise_non_unique_error
            else
              increase_error_count
              reschedule
            end
          end
          false
        else
          @uniqueness_keys ||= []
          @uniqueness_keys << new_uniqueness_key
          Services.configuration.redis.setex new_uniqueness_key, ONE_HOUR, @id
          true
        end
      end

      def call(*args)
        @service_args = args
        super
      ensure
        Services.configuration.redis.del @uniqueness_keys unless @uniqueness_keys.nil? || @uniqueness_keys.empty?
        Services.configuration.redis.del error_count_key
      end

      private

      def raise_non_unique_error(retried = false)
        message = "Service #{self.class} #{@id} with uniqueness args #{@uniqueness_args} is not unique, a similar service is already running: #{@similar_service_id}."
        message << " The service has been retried #{MAX_RETRIES} times."
        raise self.class::NotUniqueError, message
      end

      def convert_for_rescheduling(arg)
        case arg
        when Array
          arg.map do |array_arg|
            convert_for_rescheduling array_arg
          end
        when Fixnum, String, TrueClass, FalseClass, NilClass
          arg
        when object_class
          arg.id
        else
          raise "Don't know how to convert arg #{arg.inspect} for rescheduling."
        end
      end

      def reschedule
        # Convert service args for rescheduling first
        reschedule_args = @service_args.map do |arg|
          convert_for_rescheduling arg
        end
        log "Rescheduling to be executed in #{retry_delay} seconds." if self.respond_to?(:log)
        self.class.perform_in retry_delay, *reschedule_args
      end

      def error_count
        (Services.configuration.redis.get(error_count_key) || 0).to_i
      end

      def increase_error_count
        Services.configuration.redis.setex error_count_key, retry_delay + ONE_HOUR, error_count + 1
      end

      def uniqueness_key(args)
        [
          KEY_PREFIX,
          self.class.to_s.gsub(':', '_')
        ].tap do |key|
          key << Digest::MD5.hexdigest(args.to_s) unless args.empty?
        end.join(':')
      end

      def error_count_key
        [
          KEY_PREFIX,
          'errors',
          self.class.to_s.gsub(':', '_')
        ].tap do |key|
          key << Digest::MD5.hexdigest(@service_args.to_s) unless @service_args.empty?
        end.join(':')
      end

      def retry_delay
        error_count ** 3 + 5
      end
    end
  end
end
