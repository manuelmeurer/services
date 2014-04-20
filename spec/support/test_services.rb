class LongRunningService < Services::Base
  def call
    sleep 2
  end
end
