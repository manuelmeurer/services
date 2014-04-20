require 'spec_helper'

describe Services::Base do
  context 'wrapping exceptions' do
    it 'does not wrap service errors or subclasses' do
      class ServiceWithError < Services::Base
        def call
          raise Error.new('I am a service error.', nil)
        end
      end
      expect do
        ServiceWithError.call
      end.to raise_error do |error|
        expect(error).to be_a(ServiceWithError::Error)
        expect(error.message).to eq('I am a service error.')
        expect(error.nested).to be_nil
      end

      class ServiceWithCustomError < Services::Base
        CustomError = Class.new(self::Error)
        def call
          raise CustomError.new('I am a custom error.', nil)
        end
      end
      expect do
        ServiceWithCustomError.call
      end.to raise_error do |error|
        expect(error).to be_a(ServiceWithCustomError::CustomError)
        expect(error.message).to eq('I am a custom error.')
        expect(error.nested).to be_nil
      end
    end

    it 'wraps all other exceptions' do
      class ServiceWithStandardError < Services::Base
        def call
          raise 'I am a StandardError.'
        end
      end
      expect do
        ServiceWithStandardError.call
      end.to raise_error do |error|
        expect(error).to be_a(ServiceWithStandardError::Error)
        expect(error.message).to eq('I am a StandardError.')
        expect(error.nested).to be_a(StandardError)
        expect(error.nested.message).to eq('I am a StandardError.')
      end

      class ServiceWithCustomStandardError < Services::Base
        CustomStandardError = Class.new(StandardError)
        def call
          raise CustomStandardError, 'I am a custom StandardError.'
        end
      end
      expect do
        ServiceWithCustomStandardError.call
      end.to raise_error do |error|
        expect(error).to be_a(ServiceWithCustomStandardError::Error)
        expect(error.message).to eq('I am a custom StandardError.')
        expect(error.nested).to be_a(ServiceWithCustomStandardError::CustomStandardError)
        expect(error.nested.message).to eq('I am a custom StandardError.')
      end
    end
  end

  context 'checking for uniqueness' do
    it 'raises an error when the same job is executed twice' do
      LongRunningService.perform_async
      sleep 0.5 # Wait for Sidekiq to start processing the job
      expect do
        LongRunningService.call
      end.to raise_error(LongRunningService::NotUniqueError)
    end
  end
end
