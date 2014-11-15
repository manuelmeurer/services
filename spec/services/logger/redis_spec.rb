require 'spec_helper'

describe Services::Logger::Redis do
  let(:meta)        { { foo: 'bar' } }
  let(:message)     { "One day baby we'll be old" }
  let(:severity)    { 'critical' }
  let(:key)         { 'custom_log_key' }
  let(:redis)       { Redis.new }
  let(:logger)      { described_class.new(redis, key) }

  def log_entries
    redis.lrange(key, 0, -1).map do |json|
      JSON.load json
    end
  end

  def create_logs
    (2.days.ago.to_i..Time.now.to_i).step(1.hour) do |timestamp|
      time = Time.at(timestamp)
      Timecop.freeze time do
        logger.log time.to_s(:long), weekday: time.strftime('%a')
      end
    end
  end

  describe '#log' do
    it 'logs properly' do
      Timecop.freeze do
        payload = {
          'time'     => Time.now.to_i,
          'message'  => message,
          'severity' => severity,
          'meta'     => meta.stringify_keys
        }
        expect do
          logger.log message, meta, severity
        end.to change { log_entries }.from([]).to([payload])
      end
    end
  end

  context 'when logs are present' do
    before do
      create_logs
      expect(log_entries.size).to be > 0
    end

    describe '#size' do
      it 'returns the amount of logs' do
        expect(logger.size).to eq(log_entries.size)
      end
    end

    describe '#fetch' do
      it 'returns all logs' do
        expect(logger.fetch).to eq(log_entries)
      end
    end

    describe '#clear' do
      it 'returns all logs' do
        expect(log_entries).to eq(logger.clear)
      end

      it 'clears all log entries' do
        expect { logger.clear }.to change { log_entries }.to([])
      end
    end
  end
end
