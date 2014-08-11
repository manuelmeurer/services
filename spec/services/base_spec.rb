require 'spec_helper'

describe Services::Base do
  describe '#find_objects' do
    let(:objects) { (1..5).to_a.shuffle.map { |id| Model.new(id) } }

    context 'when passing in objects' do
      it 'returns the same objects' do
        expect(Services::Models::FindObjectsTest.call(objects)).to eq(objects)
      end
    end

    context 'when passing in IDs' do
      it 'returns the objects for the IDs' do
        expect(Services::Models::FindObjectsTest.call(objects.map(&:id))).to eq(objects)
      end
    end

    context 'when passing in objects and IDs' do
      it 'returns the objects plus the objects for the IDs' do
        objects_as_objects, objects_as_ids = objects.partition do |object|
          rand(2) == 1
        end

        expect(
          Services::Models::FindObjectsTest.call(objects_as_objects + objects_as_ids.map(&:id))
        ).to eq(objects_as_objects + objects_as_ids)
      end
    end
  end

  if StandardError.new.respond_to?(:cause)
    context 'wrapping exceptions' do
      it 'does not wrap service errors or subclasses' do
        expect do
          ErrorService.call
        end.to raise_error do |error|
          expect(error).to be_a(ErrorService::Error)
          expect(error.message).to eq('I am a service error.')
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

  context 'checking for uniqueness' do
    context 'when the service was set to check for uniqueness with the default args' do
      it 'raises an error when the same job is executed twice' do
        wait_for_job_to_run UniqueService.perform_async
        expect { UniqueService.call }.to raise_error(UniqueService::NotUniqueError)
      end
    end

    context 'when the service was set to check for uniqueness with custom args' do
      it 'raises an error when a job with the same custom args is executed twice' do
        wait_for_job_to_run UniqueWithCustomArgsService.perform_async('foo', 'bar', 'baz')
        expect { UniqueWithCustomArgsService.call('foo', 'bar', 'pelle') }.to raise_error(UniqueWithCustomArgsService::NotUniqueError)
        expect { UniqueWithCustomArgsService.call('foo', 'baz', 'pelle') }.to_not raise_error
      end
    end

    context 'when the service was not set to check for uniqueness' do
      it 'does not raise an error when the same job is executed twice' do
        wait_for_job_to_run NonUniqueService.perform_async
        expect { NonUniqueService.call }.to_not raise_error
      end
    end
  end

  context 'logging exceptions' do
    if RUBY_VERSION > '2.1'
      it 'logs the exception cause(s) as well' do
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

  context 'when executed asynchronously' do
    it 'finds its own worker' do
      3.times { OwnWorkerService.perform_async }
      jid = OwnWorkerService.perform_async
      own_worker_data = wait_for { Services.configuration.redis.get(jid) }
      own_worker_json = JSON.parse(own_worker_data)
      expect(own_worker_json[2]['payload']['jid']).to eq(jid)
    end

    it 'finds its sibling workers' do
      sibling_worker_jids = (1..3).map { SiblingWorkersService.perform_async }
      jid = SiblingWorkersService.perform_async
      sibling_worker_data = wait_for { Services.configuration.redis.get(jid) }
      sibling_worker_json = JSON.parse(sibling_worker_data)
      expect(sibling_worker_json.size).to eq(3)
      expected_sibling_worker_jids = sibling_worker_json.map { |_, _, work| work['payload']['jid'] }
      expect(expected_sibling_worker_jids).to match_array(sibling_worker_jids)
    end
  end
end
