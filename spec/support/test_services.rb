class UniqueService < Services::Base
  check_uniqueness!

  def call
    sleep 1
  end
end

class NonUniqueService < Services::Base
  def call
    sleep 1
  end
end
