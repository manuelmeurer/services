RSpec.shared_context 'capture logs' do
  let(:logger) { spy('logger') }
  let(:logs)   { [] }

  before do
    Services.configuration.logger = logger
    allow(logger).to receive(:log) do |message, meta, severity|
      logs << {
        message:  message,
        meta:     meta,
        severity: severity
      }
    end
  end

  after do
    Services.configuration.logger = Services::Logger::Null.new
  end
end
