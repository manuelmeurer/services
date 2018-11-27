require 'spec_helper'

describe Services::Logger::Redis do
  let(:key)    { 'custom_log_key' }
  let(:redis)  { Redis.new(url: REDIS_URL) }
  let(:logger) { described_class.new(redis, key) }
  let(:logs) {
    [
      {
        time:     Date.new(2014, 9, 15),
        message:  "One day baby we'll be old",
        severity: :info,
        meta: {
          foo:    'bar',
          class:  Services::Base.to_s,
          object: redis.to_s
        }
      }, {
        time:     Date.new(2014, 10, 10),
        message:  "Oh baby, we'll be old",
        severity: :warning,
        meta:     {
          true:  true,
          false: false,
          nil:   nil
        }
      }, {
        time:     Date.new(2014, 11, 17),
        message:  'And think of all the stories',
        severity: :critical,
        meta: {
          one:    2,
          three:  3.14
        }
      }, {
        time:     Date.new(2014, 11, 17),
        message:  'That we could have told',
        severity: :debug
      }
    ]
  }
  let(:fetched_logs) {
    logs.reverse.map do |log|
      log[:time] = log[:time].to_time
      %i(message severity).each do |k|
        log[k] = log[k].try(:to_s) || ''
      end
      log[:meta] = if log.key?(:meta)
        log[:meta].stringify_keys
      else
        {}
      end
      log.stringify_keys
    end
  }

  def create_logs
    logs.each do |log|
      Timecop.freeze log[:time] do
        args = [log[:message]]
        args.push log[:meta] || {}
        args.push log[:severity] if log.key?(:severity)
        logger.log *args
      end
    end
  end

  def logs_in_db
    redis.lrange(key, 0, -1).map do |json|
      data = JSON.load(json)
      data['time'] = Time.at(data['time'])
      data
    end
  end

  before do
    redis.del key
  end

  context 'when logs are present' do
    before do
      create_logs
      expect(logs_in_db.size).to eq(logs.size)
    end

    describe '#size' do
      it 'returns the amount of logs' do
        expect(logger.size).to eq(logs.size)
      end
    end

    describe '#fetch' do
      it 'returns all logs' do
        expect(logger.fetch).to eq(fetched_logs)
      end
    end

    describe '#clear' do
      it 'returns all logs' do
        expect(fetched_logs).to eq(logger.clear)
      end

      it 'clears all log entries' do
        expect { logger.clear }.to change { logs_in_db }.to([])
      end
    end
  end
end
