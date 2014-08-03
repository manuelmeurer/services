module Services
  class Base
    module ExceptionWrapper
      def call(*args)
        super
      rescue StandardError => e
        if e.class <= self.class::Error
          raise e
        else
          raise self.class::Error, e
        end
      end
    end
  end
end
