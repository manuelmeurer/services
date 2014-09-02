require 'spec_helper'

shared_examples 'checking the uniqueness properly' do
  it 'notices when the same job is executed multiple times' do
    wait_for_job_to_run_and_finish service, *args, 'fail', true do
      # Check that error is raised when on_error is "fail"
      if defined?(fail_args)
        3.times do
          fail_args.each do |fail_arg_group|
            expect { service.call(*fail_arg_group, 'fail', false) }.to raise_error(service::NotUniqueError)
          end
        end
      end
      if defined?(pass_args)
        3.times do
          pass_args.each do |pass_arg_group|
            expect { service.call(*pass_arg_group, 'fail', false) }.to_not raise_error
          end
        end
      end

      # Check that no error is raised when on_error is "ignore"
      if defined?(fail_args)
        3.times do
          fail_args.each do |fail_arg_group|
            expect { service.call(*fail_arg_group, 'ignore', false) }.to_not raise_error
          end
        end
      end
      if defined?(pass_args)
        3.times do
          pass_args.each do |pass_arg_group|
            expect { service.call(*pass_arg_group, 'ignore', false) }.to_not raise_error
          end
        end
      end

      # Check that service is rescheduled when on_error is "reschedule"
      if defined?(fail_args)
        3.times do
          fail_args.each do |fail_arg_group|
            expect(service).to receive(:perform_in).with(an_instance_of(Fixnum), *fail_arg_group, 'reschedule', false)
            expect { service.call(*fail_arg_group, 'reschedule', false) }.to_not raise_error
          end
        end
      end
      if defined?(pass_args)
        3.times do
          pass_args.each do |pass_arg_group|
            expect(service).to_not receive(:perform_in)
            expect { service.call(*pass_arg_group, 'reschedule', false) }.to_not raise_error
          end
        end
      end
    end

    # Check that all Redis keys are deleted
    key_pattern = "#{described_class::KEY_PREFIX}*"
    expect(Services.configuration.redis.keys(key_pattern)).to be_empty
  end
end

describe Services::Base::UniquenessChecker do
  context 'when the service checks for uniqueness with the default args' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service)   { UniqueService }
      let(:args)      { [] }
      let(:fail_args) { [] }
    end
  end

  context 'when the service checks for uniqueness with custom args' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service)   { UniqueWithCustomArgsService }
      let(:args)      { ['foo', 1, 'bar'] }
      let(:fail_args) { [['foo', 1, 'pelle']] }
      let(:pass_args) { [['foo', 2, 'bar']] }
    end
  end

  context 'when the service checks for uniqueness multiple times' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service)   { UniqueMultipleService }
      let(:args)      { ['foo', 1, true] }
      let(:fail_args) { args.map { |arg| [arg] } }
      let(:pass_args) { [%w(pelle)] }
    end
  end

  context 'when the service does not check for uniqueness' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service)   { NonUniqueService }
      let(:args)      { [] }
      let(:pass_args) { [] }
    end
  end
end
