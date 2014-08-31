require 'sidekiq/api'

ExpectedDataNotFoundError = Class.new(StandardError)

def wait_for(&block)
  50.tries on: ExpectedDataNotFoundError, delay: 0.1 do
    block.call or raise ExpectedDataNotFoundError
  end
end

def worker_with_jid(jid)
  Sidekiq::Workers.new.detect do |_, _, work|
    work['payload']['jid'] == jid
  end
end

def wait_for_all_jobs_to_finish
  wait_for do
    Sidekiq::Workers.new.size == 0
  end
end

def wait_for_job_to_run(job_class, *args, &block)
  job_class.perform_async(*args).tap do |jid|
    wait_for { worker_with_jid(jid) }
    block.call if block_given?
  end
end

def wait_for_job_to_run_and_finish(job_class, *args, &block)
  wait_for_job_to_run(job_class, *args, &block).tap do |jid|
    wait_for { worker_with_jid(jid).nil? }
  end
end
