module Services
  module Logger
    class Redis
      META_CLASSES = [
        NilClass,
        TrueClass,
        FalseClass,
        Symbol,
        String,
        Numeric
      ]

      InvalidMetaError = Class.new(StandardError)

      def initialize(redis, key = 'logs')
        @redis, @key = redis, key
      end

      def log(message, meta = {}, severity = 'info')
        # Allow only simple data types in meta
        raise InvalidMetaError, "Meta keys and values must be of one of the following classes: #{META_CLASSES.join(', ')}" if meta_includes_invalid_values?(meta)

        value = {
          time:     Time.now.to_i,
          message:  message.to_s,
          severity: severity.to_s,
          meta:     meta
        }
        @redis.lpush @key, value.to_json
      end

      def size
        @redis.llen @key
      end

      def fetch
        @redis.lrange(@key, 0, -1).map(&method(:log_entry_from_json))
      end

      def clear
        @redis.multi do
          @redis.lrange @key, 0, -1
          @redis.del @key
        end.first.map(&method(:log_entry_from_json))
      end

      private

      def log_entry_from_json(json)
        data = JSON.load(json)
        data['time'] = Time.at(data['time'])
        data
      end

      def meta_includes_invalid_values?(meta)
        [meta.values, meta.keys].any? do |elements|
          elements.any? do |element|
            META_CLASSES.none? do |klass|
              element.class <= klass
            end
          end
        end
      end
    end
  end
end
