require 'active_support/concern'

begin
  require 'sidekiq'
  require 'sidekiq/api'
rescue LoadError
  raise Services::BackgroundProcessorNotFound
end

begin
  require 'sidetiq'
rescue LoadError
end

module Services
  module Asyncable
    extend ActiveSupport::Concern

    # The name of the parameter that is added to the parameter list when calling a method to be processed in the background.
    TARGET_PARAM_NAME = :async_target_id

    included do
      include Sidekiq::Worker
      include Sidetiq::Schedulable if defined?(Sidetiq)
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

    def own_worker
      return @own_worker if defined?(@own_worker)
      @own_worker = if self.jid.nil?
        nil
      else
        own_worker = Sidekiq::Workers.new.detect do |_, _, work|
          work['payload']['jid'] == self.jid
        end
        raise self.class::Error, "Could not find own worker with jid #{self.jid}: #{Sidekiq::Workers.new.map { |*args| args }}" if own_worker.nil?
        own_worker
      end
    end

    def sibling_workers
      @sibling_workers ||= Sidekiq::Workers.new.select do |_, _, work|
        work['payload']['class'] == self.class.to_s && (own_worker.nil? || work['payload']['jid'] != own_worker[2]['payload']['jid'])
      end
    end
  end
end
