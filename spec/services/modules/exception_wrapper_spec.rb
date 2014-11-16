require 'spec_helper'

describe Services::Base::ExceptionWrapper do
  if StandardError.new.respond_to?(:cause)
    it 'does not wrap service errors or subclasses' do
      expect do
        ErrorService.call
      end.to raise_error do |error|
        expect(error).to be_a(ErrorService::Error)
        expect(error.message).to eq('I am a service error raised by ErrorService.')
        expect(error.cause).to be_nil
      end

      class ServiceWithCustomError < Services::Base
        CustomError = Class.new(self::Error)
        def call
          raise CustomError.new('I am a custom error.')
        end
      end
      expect do
        ServiceWithCustomError.call
      end.to raise_error do |error|
        expect(error).to be_a(ServiceWithCustomError::CustomError)
        expect(error.message).to eq('I am a custom error.')
        expect(error.cause).to be_nil
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
        expect(error.cause).to be_a(StandardError)
        expect(error.cause.message).to eq('I am a StandardError.')
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
        expect(error.cause).to be_a(ServiceWithCustomStandardError::CustomStandardError)
        expect(error.cause.message).to eq('I am a custom StandardError.')
      end
    end
  end
end
