class Model
  class << self
    def table_name
      'models'
    end

    # Stub ActiveRecord methods
    %i(select order where limit page per).each do |m|
      define_method m do |*args|
        self
      end
    end
  end

  attr_reader :id

  def initialize(id)
    @id = id
    ModelRepository.add self
  end

  def ==(another_model)
    self.id == another_model.id
  end
end

class ModelRepository
  def self.add(model)
    @models ||= []
    @models << model
  end

  def self.find(id)
    return nil unless defined?(@models)
    @models.detect do |model|
      model.id == id
    end
  end
end

module Services
  module Models
    class Query < Services::Query
      private

      def process(scope, conditions)
        scope
      end
    end

    class Find < Services::Base
      def call(ids)
        ids.map { |id| ModelRepository.find id }.compact
      end
    end

    class FindObjectsTest < Services::Base
      def call(ids_or_objects)
        find_objects ids_or_objects
      end
    end

    class FindObjectTest < Services::Base
      def call(id_or_object)
        find_object id_or_object
      end
    end

    class FindIdsTest < Services::Base
      def call(ids_or_objects)
        find_ids ids_or_objects
      end
    end

    class FindIdTest < Services::Base
      def call(id_or_object)
        find_id id_or_object
      end
    end
  end
end

class EmptyService < Services::Base
  def call(*args)
  end
end

class EmptyServiceWithoutCallLogging < Services::Base
  disable_call_logging

  def call(*args)
  end
end

class ErrorService < Services::Base
  def call
    raise Error, "I am a service error raised by #{self.class}."
  end
end

class ErrorServiceWithoutCallLogging < Services::Base
  disable_call_logging

  def call
    raise Error, "I am a service error raised by #{self.class}."
  end
end

class ServiceCallingService < Services::Base
  def call(service)
    service.call
  end
end

class UniqueService < Services::Base
  def call(on_error, sleep)
    check_uniqueness on_error: on_error
    do_work
    sleep 0.5 if sleep
  end
  def do_work; end
end

class UniqueWithCustomArgsService < Services::Base
  def call(uniqueness_arg1, uniqueness_arg2, ignore_arg, on_error, sleep)
    check_uniqueness uniqueness_arg1, uniqueness_arg2, on_error: on_error
    do_work
    sleep 0.5 if sleep
  end
  def do_work; end
end

class UniqueMultipleService < Services::Base
  def call(*args, on_error, sleep)
    args.each do |arg|
      check_uniqueness arg, on_error: on_error
    end
    do_work
    sleep 0.5 if sleep
  end
  def do_work; end
end

class NonUniqueService < Services::Base
  def call(on_error, sleep)
    do_work
    sleep 0.5 if sleep
  end
  def do_work; end
end

class NestedExceptionService < Services::Base
  NestedError1 = Class.new(Error)
  NestedError2 = Class.new(Error)

  def call
    begin
      begin
        raise NestedError2
      rescue NestedError2
        raise NestedError1
      end
    rescue NestedError1
      raise Error
    end
  end
end
