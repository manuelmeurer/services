require 'securerandom'
require 'action_dispatch'
require 'digest'

module Services
  class Base
    class << self
      def inherited(subclass)
        subclass.const_set :Error, Class.new(StandardError)
        subclass.send :include, Rails.application.routes.url_helpers if defined?(Rails)
        subclass.send :include, Asyncable if defined?(Asyncable)
        subclass.send :prepend, CallLogger, ExceptionWrapper, UniquenessChecker
      end

      delegate :call, to: :new
    end

    def initialize
      @id = SecureRandom.hex(6)
    end

    def call(*args)
      raise NotImplementedError
    end

    private

    def find_objects(ids_or_objects, klass = object_class)
      ids_or_objects = Array(ids_or_objects)
      ids, objects = ids_or_objects.grep(Fixnum), ids_or_objects.grep(klass)
      if ids.size + objects.size < ids_or_objects.size
        raise "All params must be either #{klass.to_s.pluralize} or Fixnums: #{ids_or_objects.map { |id_or_object| [id_or_object.class, id_or_object.inspect].join(' - ')}}"
      end
      if ids.any?
        find_service = "Services::#{klass.to_s.pluralize}::Find"
        objects_from_ids = find_service.constantize.call(ids)
        object_ids = if objects_from_ids.respond_to?(:pluck)
          objects_from_ids.pluck(:id)
        else
          objects_from_ids.map(&:id)
        end
        missing_ids = ids - object_ids
        raise self.class::Error, "#{klass.to_s.pluralize(missing_ids)} #{missing_ids.join(', ')} not found." if missing_ids.size > 0
        objects.concat objects_from_ids
      end
      objects
    end

    def find_object(*args)
      find_objects(*args).tap do |objects|
        raise "Expected exactly one object but found #{objects.size}" unless objects.size == 1
      end.first
    end

    def object_class
      self.class.to_s[/Services::([^:]+)/, 1].singularize.constantize
    rescue
      raise "Could not determine service class from #{self.class}"
    end

    def controller
      @controller ||= begin
        raise 'Please configure host.' if Services.configuration.host.nil?
        request = ActionDispatch::TestRequest.new
        request.host = Services.configuration.host
        ActionController::Base.new.tap do |controller|
          controller.instance_variable_set('@_request', request)
        end
      end
    end
  end
end
