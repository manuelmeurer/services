require 'active_support/concern'
require 'global_id'

module Services
  module Asyncable
    extend ActiveSupport::Concern

    ASYNC_METHOD_SUFFIXES = %i(async in at).freeze

    included do
      sidekiq_loaded = false

      begin
        require 'sidekiq'
        require 'sidekiq/api'
      rescue LoadError
      else
        include Sidekiq::Worker
        sidekiq_loaded = true
      end

      unless sidekiq_loaded
        begin
          require 'sucker_punch'
        rescue LoadError
          raise Services::NoBackgroundProcessorFound
        else
          include SuckerPunch::Job
        end
      end
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

      call_method = method(:call)

      # Find the first class that inherits from `Services::Base`.
      while !(call_method.owner < Services::Base)
        call_method = call_method.super_method
      end

      # If the `call` method takes any kwargs and the last argument is a hash, pass them to the method as kwargs.
      kwargs = if call_method.parameters.map(&:first).grep(/\Akey/).any? && args.last.is_a?(Hash)
        args.pop.symbolize_keys
      else
        {}
      end

      call *args, **kwargs
    end
  end
end
