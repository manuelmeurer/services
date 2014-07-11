class UniqueService < Services::Base
  check_uniqueness!

  def call
    sleep 0.5
  end
end

class NonUniqueService < Services::Base
  def call
    sleep 0.5
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
