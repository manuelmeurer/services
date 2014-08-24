module Services
  class Base
    module UniquenessChecker
      KEY_PREFIX = %w(
        services
        uniqueness
      ).join(':')

      def self.prepended(mod)
        mod.const_set :NotUniqueError, Class.new(mod::Error)
      end

      def check_uniqueness!(*args)
        if args.empty?
          raise 'Could not find uniqueness args' unless defined?(@uniqueness_args)
          args = @uniqueness_args
        end
        new_uniqueness_key = uniqueness_key(args)
        if similar_service_id = Services.configuration.redis.get(new_uniqueness_key)
          raise self.class::NotUniqueError, "Service #{self.class} with uniqueness args #{args} is not unique, a similar service is already running: #{similar_service_id}"
        else
          @uniqueness_keys ||= []
          raise "A uniqueness key with args #{args.inspect} already exists." if @uniqueness_keys.include?(new_uniqueness_key)
          @uniqueness_keys << new_uniqueness_key
          Services.configuration.redis.setex new_uniqueness_key, 60 * 60, @id
        end
      end

      def call(*args)
        @uniqueness_args = args
        super
      ensure
        Services.configuration.redis.del @uniqueness_keys unless @uniqueness_keys.nil? || @uniqueness_keys.empty?
      end

      private

      def uniqueness_key(args)
        [
          KEY_PREFIX,
          self.class.to_s
        ].tap do |key|
          key << Digest::MD5.hexdigest(args.to_s) unless args.empty?
        end.join(':')
      end
    end
  end
end
