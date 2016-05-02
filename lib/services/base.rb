require 'securerandom'
require 'action_dispatch'
require 'digest'

module Services
  class Base
    include ObjectClass

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

    def log(message, meta = {}, severity = 'info')
      Services.configuration.logger.log message, meta.merge(service: self.class.to_s, id: @id), severity
    end

    def _split_ids_and_objects(ids_or_objects, klass)
      ids_or_objects = Array(ids_or_objects)
      ids, objects = ids_or_objects.grep(Fixnum), ids_or_objects.grep(klass)
      if ids.size + objects.size < ids_or_objects.size
        raise "All params must be either #{klass.to_s.pluralize} or Fixnums: #{ids_or_objects.map { |id_or_object| [id_or_object.class, id_or_object.inspect].join(' - ')}}"
      end
      [ids, objects]
    end

    def find_ids(ids_or_objects, klass = object_class)
      ids, objects = _split_ids_and_objects(ids_or_objects, klass)
      ids.concat objects.map(&:id) if objects.any?
      ids
    end

    def find_service(klass)
      find_service_name = "#{klass.to_s.pluralize}::Find"
      candidates = [find_service_name, "Services::#{find_service_name}"]
      candidates.map(&:safe_constantize).compact.first or raise self.class::Error, "Could not find find service (tried: #{candidates.join(', ')})"
    end

    def find_objects(ids_or_objects, klass = object_class)
      ids, objects = _split_ids_and_objects(ids_or_objects, klass)
      if ids.any?
        objects_from_ids = find_service(klass).call(ids)
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

    %i(object id).each do |type|
      define_method "find_#{type}" do |*args|
        send("find_#{type.to_s.pluralize}", *args).tap do |objects_or_ids|
          raise "Expected exactly one object or ID but found #{objects_or_ids.size}." unless objects_or_ids.size == 1
        end.first
      end
    end
  end
end
