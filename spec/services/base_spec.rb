require 'spec_helper'

describe Services::Base do
  let(:model_objects) { (1..5).to_a.shuffle.map { |id| Model.new(id) } }

  describe '#find_objects' do
    context 'when passing in objects' do
      it 'returns the same objects' do
        expect(Services::Models::FindObjectsTest.call(model_objects)).to eq(model_objects)
      end
    end

    context 'when passing in IDs' do
      it 'returns the objects for the IDs' do
        expect(Services::Models::FindObjectsTest.call(model_objects.map(&:id))).to eq(model_objects)
      end
    end

    context 'when passing in objects and IDs' do
      it 'returns the objects plus the objects for the IDs' do
        objects_as_objects, objects_as_ids = model_objects.partition do |object|
          rand(2) == 1
        end

        objects_and_ids = objects_as_objects + objects_as_ids.map(&:id)
        only_objects = objects_as_objects + objects_as_ids

        expect(Services::Models::FindObjectsTest.call(objects_and_ids)).to eq(only_objects)
      end
    end

    context 'when passing in a single object or ID' do
      it 'returns an array containing the object' do
        object = model_objects.sample
        [object.id, object].each do |id_or_object|
          expect(Services::Models::FindObjectsTest.call(id_or_object)).to eq([object])
        end
      end
    end
  end

  describe '#find_object' do
    context 'when passing in a single object or ID' do
      it 'returns the object' do
        object = model_objects.sample
        [object.id, object].each do |id_or_object|
          expect(Services::Models::FindObjectTest.call(id_or_object)).to eq(object)
        end
      end
    end

    context 'when passing in something else than a single object or ID' do
      it 'raises an error' do
        [%w(foo bar), nil, Object.new].each do |object|
          expect { Services::Models::FindObjectTest.call(object) }.to raise_error
        end
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
    context 'when the service checks for uniqueness with the default args' do
      it 'raises an error when the same job is executed twice' do
        wait_for_job_to_run UniqueService do
          expect { UniqueService.call }.to raise_error(UniqueService::NotUniqueError)
        end
      end
    end

    context 'when the service checks for uniqueness with custom args' do
      it 'raises an error when a job with the same custom args is executed twice' do
        wait_for_job_to_run UniqueWithCustomArgsService, 'foo', 'bar', 'baz' do
          expect { UniqueWithCustomArgsService.call('foo', 'bar', 'pelle') }.to raise_error(UniqueWithCustomArgsService::NotUniqueError)
          expect { UniqueWithCustomArgsService.call('foo', 'baz', 'pelle') }.to_not raise_error
        end
      end
    end

    context 'when the service checks for uniqueness multiple times' do
      let(:args) { %w(foo bar baz) }

      it 'raises an error when one of the checks fails' do
        wait_for_job_to_run UniqueMultipleService, *args do
          args.each do |arg|
            expect { UniqueMultipleService.call(arg) }.to raise_error(UniqueMultipleService::NotUniqueError)
          end
          expect { UniqueMultipleService.call('pelle') }.to_not raise_error
        end
      end

      it 'does not leave any Redis keys behind' do
        expect do
          wait_for_job_to_run_and_finish UniqueMultipleService, *args do
            args.each do |arg|
              UniqueMultipleService.call(arg) rescue nil
            end
            UniqueMultipleService.call('pelle')
          end
        end.to_not change {
          Services.configuration.redis.keys("*#{Services::Base::UniquenessChecker::KEY_PREFIX}*").count
        }
      end
    end

    context 'when the service was not set to check for uniqueness' do
      it 'does not raise an error when the same job is executed twice' do
        wait_for_job_to_run NonUniqueService do
          expect { NonUniqueService.call }.to_not raise_error
        end
      end
    end
  end

  context 'logging' do
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
