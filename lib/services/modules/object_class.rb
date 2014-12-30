module Services
  module ObjectClass
    private def object_class
      self.class.to_s[/\AServices::([^:]+)/, 1].singularize.constantize
    rescue
      raise "Could not determine service class from #{self.class}."
    end
  end
end
