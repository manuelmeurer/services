require 'gem_config'

module Services
  include GemConfig::Base

  BackgroundProcessorNotFound = Class.new(StandardError)

  with_configuration do
    has :host, classes: String
    has :log_dir, classes: [String, Pathname]
    has :redis
  end
end

require_relative 'services/version'
require_relative 'services/logger'
begin
  require_relative 'services/asyncable'
rescue Services::BackgroundProcessorNotFound
end
require_relative 'services/base/call_logger'
require_relative 'services/base/exception_Wrapper'
require_relative 'services/base/uniqueness_checker'
require_relative 'services/base'
require_relative 'services/railtie' if defined?(Rails)
