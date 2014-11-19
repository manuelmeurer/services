require 'spec_helper'

describe Services::Base::CallLogger do
  include_context 'capture logs'

  context 'when call logging is enabled' do
    it 'logs start and end' do
      service, args = EmptyService.new, %w(foo bar)
      service.call *args
      caller_regex = /\A#{Regexp.escape __FILE__}:\d+\z/
      expect(logs.first).to match(
        message:  "START with args: #{args}",
        meta: {
          caller:  a_string_matching(caller_regex),
          service: service.class.to_s,
          id:      an_instance_of(String)
        },
        severity: 'info'
      )
      expect(logs.last).to match(
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
        caller_regex = /\A#{Regexp.escape __FILE__}:\d+/
        expect(
          logs.detect do |log|
            log[:meta][:caller] =~ caller_regex
          end
        ).to be_present
      end

      context 'when Rails is not defined' do
        it 'logs the complete caller path' do
          service_calling_service.call called_service
          caller_regex = /\A#{Regexp.escape PROJECT_ROOT.join(TEST_SERVICES_PATH).to_s}:\d+/
          expect(
            logs.detect do |log|
              log[:meta][:caller] =~ caller_regex
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
          caller_regex = /\A#{Regexp.escape TEST_SERVICES_PATH.to_s}:\d+/
          expect(
            logs.detect do |log|
              log[:meta][:caller] =~ caller_regex
            end
          ).to be_present
        end
      end
    end
  end

  context 'when call logging is disabled' do
    it 'does not log start and end' do
      expect(EmptyServiceWithoutCallLogging.call_logging_disabled).to eq(true)
      expect { EmptyServiceWithoutCallLogging.call }.to_not change { logs }
    end
  end

  it 'logs exceptions' do
    [ErrorService, ErrorServiceWithoutCallLogging].each do |klass|
      expect { klass.call rescue nil }.to change { logs }
    end
  end

  if RUBY_VERSION > '2.1'
    it 'logs exception causes' do
      service = NestedExceptionService.new
      expect { service.call }.to raise_error(service.class::Error)
      %w(NestedError1 NestedError2).each do |error|
        message_regex = /caused by: #{service.class}::#{error}/
        expect(
          logs.detect do |log|
            log[:message] =~ message_regex
          end
        ).to be_present
      end
    end
  end
end
