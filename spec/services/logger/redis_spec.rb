require 'spec_helper'

describe Services::Logger::Redis do
  let(:tags)        { %w(foo bar baz) }
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

  describe '#log' do
    it 'logs properly' do
      Timecop.freeze do
        payload = {
          'time'     => Time.now.to_i,
          'message'  => message,
          'severity' => severity,
          'tags'     => tags
        }
        expect do
          logger.log tags, message, severity
        end.to change { log_entries }.from([]).to([payload])
      end
    end
  end

  describe '#clear' do
    before do
      (2.days.ago.to_i..Time.now.to_i).step(1.hour) do |timestamp|
        time = Time.at(timestamp)
        Timecop.freeze time do
          tags = [time.strftime('%a')]
          logger.log tags, time.to_s(:long)
        end
      end
      expect(log_entries.size).to be > 0
    end

    it 'returns all log entries' do
      expect(log_entries).to eq(logger.clear)
    end

    it 'clears all log entries' do
      expect do
        logger.clear
      end.to change { log_entries }.to([])
    end
  end
end
