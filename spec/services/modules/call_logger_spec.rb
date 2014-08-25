require 'spec_helper'

describe Services::Base::CallLogger do
  it 'logs start with args and end with duration' do
    service = EmptyService.new
    logs = []
    allow(service).to receive(:log) do |message, *|
      logs << message
    end
    service.call 'foo', 'bar'
    expect(logs.first).to eq('START with args ["foo", "bar"]')
    expect(logs.last).to eq('END after 0.0 seconds')
  end

  it 'logs the caller' do
    service_calling_service, called_service = ServiceCallingService.new, EmptyService.new
    logs = []
    allow(called_service).to receive(:log) do |message, *|
      logs << message
    end

    # When Rails is not defined, the complete caller path should be logged
    service_calling_service.call called_service
    expect(logs).to include(/\ACALLED BY #{Regexp.escape(PROJECT_ROOT.join(SERVICES_PATH).to_s)}:\d+/)

    # When Rails is defined, only the caller path relative to Rails.root is logged
    class Rails
      def self.root; PROJECT_ROOT; end
    end
    logs = []
    service_calling_service.call called_service
    expect(logs).to include(/\ACALLED BY #{Regexp.escape(SERVICES_PATH)}:\d+/)
    Object.send :remove_const, :Rails
  end

  if RUBY_VERSION > '2.1'
    it 'logs exceptions and exception causes' do
      service = NestedExceptionService.new
      logs = []
      allow(service).to receive(:log) do |message, *|
        logs << message
      end
      expect { service.call }.to raise_error(NestedExceptionService::Error)
      %w(NestedError1 NestedError2).each do |error|
        expect(logs).to include(/\Acaused by: NestedExceptionService::#{error}/)
      end
    end
  end
end
