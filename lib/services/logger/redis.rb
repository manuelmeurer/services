module Services
  module Logger
    class Redis
      def initialize(redis, key = 'logs')
        @redis, @key = redis, key
      end

      def log(message, meta = {}, severity = :info)
        value = {
          time:     Time.now.to_i,
          message:  message.to_s,
          severity: severity.to_s,
          meta:     meta.map { |k, v| [k.to_s, v.to_s] }.to_h
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
    end
  end
end
