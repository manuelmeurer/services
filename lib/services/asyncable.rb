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

    included do
      include Sidekiq::Worker
    end

    module ClassMethods
      # Bulk enqueue items
      # args can either be a one-dimensional or two-dimensional array,
      # each item in args should be the arguments for one job.
      def bulk_perform_async(args)
        # Convert args to two-dimensional array if it isn't already.
        args = args.map { |arg| [arg] } if args.none? { |arg| arg.is_a?(Array) }
        Sidekiq::Client.push_bulk 'class' => self, 'args' => args
      end
    end

    %w(perform_async perform_in).each do |method_name|
      define_method method_name do |*args|
        self.class.send method_name, *args, TARGET_PARAM_NAME => self.id
      end
    end
    alias_method :perform_at, :perform_in

    def perform(*args)
      return self.call(*args) if self.is_a?(Services::Base)

      target = if args.last.is_a?(Hash) && args.last.keys.first.to_sym == TARGET_PARAM_NAME
        self.class.find args.pop.values.first
      else
        self.class
      end

      target.send *args
    end
  end
end
