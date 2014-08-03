module Services
  class Base
    module UniquenessChecker
      def self.prepended(mod)
        mod.const_set :NotUniqueError, Class.new(mod::Error)
      end

      def check_uniqueness!(*args)
        raise 'A variable named @uniqueness_key is already defined. Have you called `check_uniqueness!` twice?' if defined?(@uniqueness_key)
        args = method(__method__).parameters.map { |arg| eval arg[1].to_s } if args.empty?
        @uniqueness_key = uniqueness_key(args)
        if Services.configuration.redis.exists(@uniqueness_key)
          raise self.class::NotUniqueError
        else
          Services.configuration.redis.setex @uniqueness_key, 60 * 60, Time.now
        end
      end

      def call(*args)
        super
      ensure
        Services.configuration.redis.del @uniqueness_key if defined?(@uniqueness_key)
      end

      private

      def uniqueness_key(args)
        [
          'services',
          'uniqueness',
          self.class.to_s,
          Digest::MD5.hexdigest(args.to_s)
        ].join(':')
      end
    end
  end
end
