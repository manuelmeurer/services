class Model
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
  end
end

class EmptyService < Services::Base
  def call(*args)
  end
end

class ErrorService < Services::Base
  def call
    raise Error.new('I am a service error.')
  end
end

class ServiceCallingService < Services::Base
  def call(service)
    service.call
  end
end

class UniqueService < Services::Base
  def call(on_error, sleep)
    check_uniqueness! on_error: on_error
    sleep 0.5 if sleep
  end
end

class UniqueWithCustomArgsService < Services::Base
  def call(uniqueness_arg1, uniqueness_arg2, ignore_arg, on_error, sleep)
    check_uniqueness! uniqueness_arg1, uniqueness_arg2, on_error: on_error
    sleep 0.5 if sleep
  end
end

class UniqueMultipleService < Services::Base
  def call(*args, on_error, sleep)
    args.each do |arg|
      check_uniqueness! arg, on_error: on_error
    end
    sleep 0.5 if sleep
  end
end

class NonUniqueService < Services::Base
  def call(on_error, sleep)
    sleep 0.5 if sleep
  end
end

class OwnWorkerService < Services::Base
  def call
    if own_worker.nil?
      logger.error 'Could not find own worker!'
    else
      Services.configuration.redis.set self.jid, own_worker.to_json
    end
    sleep 0.5
  end
end

class SiblingWorkersService < Services::Base
  def call
    if sibling_workers.empty?
      logger.info 'No sibling workers found.'
    else
      Services.configuration.redis.set self.jid, sibling_workers.to_json
    end
    sleep 0.5
  end
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
