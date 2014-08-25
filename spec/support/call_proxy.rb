# This is just a helper file to ensure that
# the services lib folder appears in the caller
# locations.

module Services
  class CallProxy
    def self.call(object, method)
      object.public_send method
    end
  end
end
