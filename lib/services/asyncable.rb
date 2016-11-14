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

    # The name of the parameter that is added to the parameter list when calling a method to be processed in the background.
    TARGET_PARAM_NAME = :async_target_id

    ASYNC_METHOD_SUFFIXES = %i(async in at)

    included do
      include Sidekiq::Worker
    end

    module ClassMethods
      # Bulk enqueue items
      # args can either be a one-dimensional or two-dimensional array,
      # each item in args should be the arguments for one job.
      def bulk_call_async(args)
        # Convert args to two-dimensional array if it isn't one already.
        args = args.map { |arg| [arg] } if args.none? { |arg| arg.is_a?(Array) }
        Sidekiq::Client.push_bulk 'class' => self, 'args' => args
      end

      ASYNC_METHOD_SUFFIXES.each do |async_method_suffix|
        define_method "call_#{async_method_suffix}" do |*args|
          self.public_send "perform_#{async_method_suffix}", *args
        end
      end
    end

    ASYNC_METHOD_SUFFIXES.each do |async_method_suffix|
      define_method "call_#{async_method_suffix}" do |*args|
        self.class.public_send "perform_#{async_method_suffix}", *args, TARGET_PARAM_NAME => self.id
      end
    end

    def perform(*args)
      return self.call(*args) if self.is_a?(Services::Base)

      target = if args.last.is_a?(Hash) && args.last.keys.first.to_sym == TARGET_PARAM_NAME
        self.class.find args.pop.values.first
      else
        self.class
      end

      target.public_send *args
    end
  end
end
