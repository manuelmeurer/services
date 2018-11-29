require 'active_support/concern'
require 'global_id'

begin
  require 'sidekiq'
  require 'sidekiq/api'
rescue LoadError
  raise Services::BackgroundProcessorNotFound
end

module Services
  module Asyncable
    extend ActiveSupport::Concern

    ASYNC_METHOD_SUFFIXES = %i(async in at).freeze

    included do
      include Sidekiq::Worker
    end

    module ClassMethods
      ASYNC_METHOD_SUFFIXES.each do |async_method_suffix|
        define_method "call_#{async_method_suffix}" do |*args|
          args = args.map do |arg|
            arg.respond_to?(:to_global_id) ? arg.to_global_id : arg
          end
          self.public_send "perform_#{async_method_suffix}", *args
        end
      end
    end

    def perform(*args)
      args = args.map do |arg|
        GlobalID::Locator.locate(arg) || arg
      end
      # If the `call` method takes any kwargs and the last argument is a hash, symbolize the hash keys,
      # otherwise they won't be recognized as kwards when splatted.
      # Since the arguments to `perform` are serialized to the database before Sidekiq picks them up,
      # symbol keys are converted to strings.
      call_method = method(:call)
      while call_method.owner != self.class
        call_method = call_method.super_method
      end
      if call_method.parameters.map(&:first).grep(/\Akey/).any? && args.last.is_a?(Hash)
        args.last.symbolize_keys!
      end
      call *args
    end
  end
end
