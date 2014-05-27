module Services
  class Base
    module UniquenessChecker
      def self.prepended(mod)
        mod.instance_eval do
          def check_uniqueness?
            @check_uniqueness
          end

          def check_uniqueness!
            @check_uniqueness = true
          end
        end
        mod.const_set :NotUniqueError, Class.new(mod::Error)
      end

      def call(*args)
        if self.class.check_uniqueness?
          key = unique_key(args)
          if Services.configuration.redis.exists(key)
            raise self.class::NotUniqueError
          else
            Services.configuration.redis.setex key, 60 * 60, Time.now
            begin
              super
            ensure
              Services.configuration.redis.del key
            end
          end
        else
          super
        end
      end

      private

      def unique_key(args)
        # TODO: symbolize keys in hashes in args and sort hashes by key
        args = args.dup
        key = [
          'services',
          'uniqueness',
          self.class.to_s,
          Digest::MD5.hexdigest(args.to_s)
        ].join(':')
      end
    end
  end
end
