require 'spec_helper'

describe Services::Base::CallLogger do
  let(:logger) { spy('logger') }

  before do
    Services.configuration.logger = logger
    @logs = []
    allow(logger).to receive(:log) do |message, meta, severity|
      @logs << {
        message:  message,
        meta:     meta,
        severity: severity
      }
    end
  end

  it 'logs start with args and end with duration' do
    service, args = EmptyService.new, %w(foo bar)
    service.call *args
    expect(@logs.first).to match(
      message:  "START with args: #{args}",
      meta: {
        caller:  a_string_matching(/\A#{Regexp.escape __FILE__}:\d+\z/),
        service: service.class.to_s,
        id:      an_instance_of(String)
      },
      severity: 'info'
    )
    expect(@logs.last).to match(
      message: 'END',
      meta: {
        duration: 0.0,
        service:  service.class.to_s,
        id:       an_instance_of(String)
      },
      severity: 'info'
    )
  end

  describe 'logging the caller' do
    let(:service_calling_service) { ServiceCallingService.new }
    let(:called_service) { EmptyService.new }

    it 'filters out caller paths from lib folder' do
      require 'services/call_proxy'
      Services::CallProxy.call(called_service, :call)
      expect(
        @logs.detect do |log|
          log[:meta][:caller] =~ /\A#{Regexp.escape __FILE__}:\d+/
        end
      ).to be_present
    end

    context 'when Rails is not defined' do
      it 'logs the complete caller path' do
        service_calling_service.call called_service
        expect(
          @logs.detect do |log|
            log[:meta][:caller] =~ /\A#{Regexp.escape PROJECT_ROOT.join(TEST_SERVICES_PATH).to_s}:\d+/
          end
        ).to be_present
      end
    end

    context 'when Rails is defined' do
      before do
        class Rails
          def self.root
            PROJECT_ROOT
          end
        end
      end

      after do
        Object.send :remove_const, :Rails
      end

      it 'logs the caller path relative to `Rails.root`' do
        service_calling_service.call called_service
        expect(
          @logs.detect do |log|
            log[:meta][:caller] =~ /\A#{Regexp.escape TEST_SERVICES_PATH.to_s}:\d+/
          end
        ).to be_present
      end
    end
  end

  if RUBY_VERSION > '2.1'
    it 'logs exceptions and exception causes' do
      service = NestedExceptionService.new
      expect { service.call }.to raise_error(service.class::Error)
      %w(NestedError1 NestedError2).each do |error|
        expect(
          @logs.detect do |log|
            log[:message] =~ /caused by: #{service.class}::#{error}/
          end
        ).to be_present
      end
    end
  end
end
