require 'gem_config'

require_relative 'services/logger/null'

module Services
  include GemConfig::Base

  NoBackgroundProcessorFound = Class.new(StandardError)
  RedisNotFound              = Class.new(StandardError)

  with_configuration do
    has :logger, default: Services::Logger::Null.new
    has :redis
    has :allowed_class_methods_in_queries, default: {}
  end

  class << self
    def redis
      @redis ||= configuration.redis || (defined?(Redis.current) && Redis.current) or fail RedisNotFound, 'Redis not configured.'
    end

    def allow_class_method_in_queries(klass, method, arity = nil)
      (configuration.allowed_class_methods_in_queries[klass.to_s] ||= {})[method.to_sym] = arity
    end

    def replace_records_with_global_ids(arg)
      method = method(__method__)

      case arg
      when Array then arg.map(&method)
      when Hash  then arg.transform_keys(&method)
                         .transform_values(&method)
      else arg.respond_to?(:to_global_id) ? "_#{arg.to_global_id.to_s}" : arg
      end
    end

    def replace_global_ids_with_records(arg)
      method = method(__method__)

      case arg
      when Array  then arg.map(&method)
      when Hash   then arg.transform_keys(&method)
                          .transform_values(&method)
      when String then (arg.starts_with?("_") && GlobalID::Locator.locate(arg[1..-1])) || arg
      else arg
      end
    end
  end
end

require_relative 'services/version'
require_relative 'services/logger/file'
require_relative 'services/logger/redis'
require_relative 'services/asyncable'
require_relative 'services/modules/call_logger'
require_relative 'services/modules/exception_wrapper'
require_relative 'services/modules/object_class'
require_relative 'services/modules/uniqueness_checker'
require_relative 'services/base'
require_relative 'services/query'
require_relative 'services/railtie' if defined?(Rails)
