require 'spec_helper'

describe Services::Base::UniquenessChecker do
  context 'when the service checks for uniqueness with the default args' do
    it 'raises an error when the same job is executed multiple times' do
      wait_for_job_to_run UniqueService do
        3.times do
          expect { UniqueService.call }.to raise_error(UniqueService::NotUniqueError)
        end
      end
    end
  end

  context 'when the service checks for uniqueness with custom args' do
    it 'raises an error when a job with the same custom args is executed multiple times' do
      wait_for_job_to_run UniqueWithCustomArgsService, 'foo', 'bar', 'baz' do
        3.times do
          expect { UniqueWithCustomArgsService.call('foo', 'bar', 'pelle') }.to raise_error(UniqueWithCustomArgsService::NotUniqueError)
        end
        expect { UniqueWithCustomArgsService.call('foo', 'baz', 'pelle') }.to_not raise_error
      end
    end
  end

  context 'when the service checks for uniqueness multiple times' do
    let(:args) { %w(foo bar baz) }

    it 'raises an error when one of the checks fails' do
      wait_for_job_to_run UniqueMultipleService, *args do
        args.each do |arg|
          3.times do
            expect { UniqueMultipleService.call(arg) }.to raise_error(UniqueMultipleService::NotUniqueError)
          end
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
