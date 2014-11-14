module Services
  module Logger
    class Redis
      def initialize(redis, key = 'logs')
        @redis, @key = redis, key
      end

      def log(message, tags = [], severity = :info)
        value = {
          time:     Time.now.to_i,
          message:  message,
          severity: severity,
          tags:     tags
        }
        @redis.lpush @key, value.to_json
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
