module Services
  class Base
    module UniquenessChecker
      def self.prepended(mod)
        mod.const_set :NotUniqueError, Class.new(mod::Error)
      end

      def check_uniqueness!(*args)
        raise 'A variable named @uniqueness_key is already defined. Have you called `check_uniqueness!` twice?' if defined?(@uniqueness_key)
        raise 'Could not find @uniqueness_all_args' unless defined?(@uniqueness_all_args)
        args = @uniqueness_all_args if args.empty?
        @uniqueness_key = uniqueness_key(args)
        if similar_service_id = Services.configuration.redis.get(@uniqueness_key)
          raise self.class::NotUniqueError, "Service #{self.class} with args #{args} is not unique, a similar service is already running: #{similar_service_id}"
        else
          Services.configuration.redis.setex @uniqueness_key, 60 * 60, @id
        end
      end

      def call(*args)
        @uniqueness_all_args = args
        super
      ensure
        Services.configuration.redis.del @uniqueness_key if defined?(@uniqueness_key)
      end

      private

      def uniqueness_key(args)
        [
          'services',
          'uniqueness',
          self.class.to_s
        ].tap do |key|
          key << Digest::MD5.hexdigest(args.to_s) unless args.empty?
        end.join(':')
      end
    end
  end
end
