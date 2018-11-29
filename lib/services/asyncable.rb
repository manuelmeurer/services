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
      call *args
    end
  end
end
