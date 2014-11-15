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
        @redis.lrange(@key, 0, -1).map do |json|
          JSON.load json
        end
      end

      def clear
        @redis.multi do
          @redis.lrange @key, 0, -1
          @redis.del @key
        end.first.map do |json|
          JSON.load json
        end
      end
    end
  end
end
