require 'active_support/concern'

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
          self.public_send "perform_#{async_method_suffix}", *args
        end
      end
    end

    def perform(*args)
      self.call *args
    end
  end
end
