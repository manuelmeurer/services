module Services
  class Base
    module UniquenessChecker
      KEY_PREFIX = %w(
        services
        uniqueness
      ).join(':').freeze

      ON_ERROR = %i(
        fail
        ignore
        reschedule
        return
      ).freeze

      MAX_RETRIES = 10.freeze
      ONE_DAY     = (60 * 60 * 24).freeze

      def self.prepended(mod)
        mod.const_set :NotUniqueError, Class.new(mod::Error)
      end

      def check_uniqueness(*args, on_error: :fail)
        raise "on_error must be one of #{ON_ERROR.join(', ')}, but was #{on_error}" unless ON_ERROR.include?(on_error.to_sym)
        @_on_error = on_error
        raise 'Service args not found.' if @_service_args.nil?
        @_uniqueness_args = args.empty? ? @_service_args : args
        new_uniqueness_key = uniqueness_key(@_uniqueness_args)
        raise "A uniqueness key with args #{@_uniqueness_args.inspect} already exists." if @_uniqueness_keys && @_uniqueness_keys.include?(new_uniqueness_key)
        if @_similar_service_id = Services.redis.get(new_uniqueness_key)
          if on_error.to_sym == :ignore
            return false
          else
            @_retries_exhausted = on_error.to_sym == :reschedule && error_count >= MAX_RETRIES
            raise_not_unique_error
          end
        else
          @_uniqueness_keys ||= []
          @_uniqueness_keys << new_uniqueness_key
          Services.redis.setex new_uniqueness_key, ONE_DAY, @id
          true
        end
      end

      def call(*args)
        @_service_args = args
        super
      rescue self.class::NotUniqueError => e
        case @_on_error.to_sym
        when :fail
          raise e
        when :reschedule
          if @_retries_exhausted
            raise e
          else
            increase_error_count
            reschedule
          end
        when :return
          return e
        else
          raise "Unexpected on_error: #{@_on_error}"
        end
      ensure
        Services.redis.del @_uniqueness_keys unless Array(@_uniqueness_keys).empty?
        Services.redis.del error_count_key
      end

      private

      def raise_not_unique_error
        message = "Service #{self.class} #{@id} with uniqueness args #{@_uniqueness_args} is not unique, a similar service is already running: #{@_similar_service_id}."
        message << " The service has been retried #{MAX_RETRIES} times." if @_retries_exhausted
        raise self.class::NotUniqueError.new(message)
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
        reschedule_args = @_service_args.map do |arg|
          convert_for_rescheduling arg
        end
        log "Rescheduling to be executed in #{retry_delay} seconds." if self.respond_to?(:log)
        self.class.call_in retry_delay, *reschedule_args
      end

      def error_count
        (Services.redis.get(error_count_key) || 0).to_i
      end

      def increase_error_count
        Services.redis.setex error_count_key, retry_delay + ONE_DAY, error_count + 1
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
          key << Digest::MD5.hexdigest(@_service_args.to_s) unless @_service_args.empty?
        end.join(':')
      end

      def retry_delay
        error_count ** 3 + 5
      end
    end
  end
end
