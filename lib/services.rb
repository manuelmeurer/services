require 'gem_config'

require_relative 'services/logger/null'

module Services
  include GemConfig::Base

  BackgroundProcessorNotFound = Class.new(StandardError)
  RedisNotFound               = Class.new(StandardError)

  with_configuration do
    has :logger, default: Services::Logger::Null.new
    has :redis
    has :allowed_class_methods_in_queries, default: {}
  end

  def self.redis
    @redis ||= self.configuration.redis || (defined?(Redis.current) && Redis.current) or fail RedisNotFound, 'Redis not configured.'
  end

  def self.allow_class_method_in_queries(klass, method, arity = nil)
    (configuration.allowed_class_methods_in_queries[klass.to_s] ||= {})[method.to_sym] = arity
  end
end

require_relative 'services/version'
require_relative 'services/logger/file'
require_relative 'services/logger/redis'
begin
  require_relative 'services/asyncable'
rescue Services::BackgroundProcessorNotFound
end
require_relative 'services/modules/call_logger'
require_relative 'services/modules/exception_wrapper'
require_relative 'services/modules/object_class'
require_relative 'services/modules/uniqueness_checker'
require_relative 'services/base'
require_relative 'services/query'
require_relative 'services/railtie' if defined?(Rails)
