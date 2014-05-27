require 'nesty'
require 'securerandom'
require 'action_dispatch'
require 'digest'

module Services
  class Base
    class << self
      def inherited(subclass)
        subclass.const_set :Error, Class.new(Nesty::NestedStandardError)
        subclass.send :include, Rails.application.routes.url_helpers if defined?(Rails)
        subclass.send :include, Asyncable if defined?(Asyncable)
        subclass.send :prepend, CallLogger, ExceptionWrapper, UniquenessChecker
      end

      delegate :call, to: :new
    end

    def initialize
      @id = SecureRandom.hex(6)
      @logger = Logger.new
    end

    def call(*args)
      raise NotImplementedError
    end

    private

    def find_object(ids_or_objects, klass = nil)
      if klass.nil?
        klass = self.class.to_s[/Services::([^:]+)/, 1].singularize.constantize rescue nil
        raise "Could not determine class from #{self.class}" if klass.nil?
      end
      case ids_or_objects
      when klass
        return ids_or_objects
      when Array
        raise 'Array can only contain IDs.' if ids_or_objects.any? { |ids_or_object| !ids_or_object.is_a?(Fixnum) }
        objects = "Services::#{klass.to_s.pluralize}::Find".constantize.call(ids_or_objects)
        missing_ids = ids_or_objects - objects.pluck(:id)
        raise self.class::Error, "#{klass.to_s.pluralize(missing_ids)} #{missing_ids.join(', ')} not found." if missing_ids.size > 0
        return objects
      when Fixnum
        object = "Services::#{klass.to_s.pluralize}::Find".constantize.call(ids_or_objects).first
        raise self.class::Error, "#{klass} #{ids_or_objects} not found." if object.nil?
        return object
      else
        raise "Unexpected ids_or_objects class: #{ids_or_objects.class}"
      end
    end

    def log(message, severity = :info)
      @logger.log [self.class, @id], message, severity
    end

    def controller
      @controller ||= begin
        raise 'Please configure host.' unless Services.configuration.host?
        request = ActionDispatch::TestRequest.new
        request.host = Services.configuration.host
        ActionController::Base.new.tap do |controller|
          controller.instance_variable_set('@_request', request)
        end
      end
    end
  end
end
