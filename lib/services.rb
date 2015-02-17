require 'gem_config'

module Services
  include GemConfig::Base

  BackgroundProcessorNotFound = Class.new(StandardError)

  with_configuration do
    has :logger
    has :redis
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
