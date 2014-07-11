require 'sidekiq/api'

ExpectedDataNotFoundError = Class.new(StandardError)

def wait_for(&block)
  10.tries on: ExpectedDataNotFoundError, delay: 0.1 do
    block.call or raise ExpectedDataNotFoundError
  end
end

def wait_for_job_to_run(jid)
  wait_for do
    Sidekiq::Workers.new.any? do |_, _, work|
      work['payload']['jid'] == jid
    end
  end
end
