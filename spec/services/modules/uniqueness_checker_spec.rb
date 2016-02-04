require 'spec_helper'

shared_examples 'checking the uniqueness properly' do
  it 'notices when the same job is executed multiple times' do
    wait_for_job_to_run_and_finish service_class, *args, 'fail', true do
      # Check that error is raised when on_error is "fail"
      puts 'Checking on_error = fail'
      if defined?(fail_args)
        puts "* with fail args #{fail_args}"
        3.times do
          fail_args.each do |fail_arg_group|
            service = service_class.new
            expect(service).to_not receive(:do_work)
            expect { service.call(*fail_arg_group, 'fail', false) }.to raise_error(service_class::NotUniqueError)
          end
        end
      end
      if defined?(pass_args)
        puts "* with pass args #{pass_args}"
        3.times do
          pass_args.each do |pass_arg_group|
            service = service_class.new
            expect(service).to receive(:do_work)
            expect { service.call(*pass_arg_group, 'fail', false) }.to_not raise_error
          end
        end
      end

      # Check that no error is raised when on_error is "ignore"
      puts 'Checking on_error = ignore'
      if defined?(fail_args)
        puts "* with fail args #{fail_args}"
        3.times do
          fail_args.each do |fail_arg_group|
            service = service_class.new
            expect(service).to receive(:do_work)
            expect { service.call(*fail_arg_group, 'ignore', false) }.to_not raise_error
          end
        end
      end
      if defined?(pass_args)
        puts "* with pass args #{pass_args}"
        3.times do
          pass_args.each do |pass_arg_group|
            service = service_class.new
            expect(service).to receive(:do_work)
            expect { service.call(*pass_arg_group, 'ignore', false) }.to_not raise_error
          end
        end
      end

      # Check that service is rescheduled when on_error is "reschedule"
      puts 'Checking on_error = reschedule'
      if defined?(fail_args)
        puts "* with fail args #{fail_args}"
        3.times do
          fail_args.each do |fail_arg_group|
            service = service_class.new
            expect(service).to_not receive(:do_work)
            expect(service_class).to receive(:perform_in).with(an_instance_of(Fixnum), *fail_arg_group, 'reschedule', false)
            expect { service.call(*fail_arg_group, 'reschedule', false) }.to_not raise_error
          end
        end
      end
      if defined?(pass_args)
        puts "* with pass args #{pass_args}"
        3.times do
          pass_args.each do |pass_arg_group|
            service = service_class.new
            expect(service).to receive(:do_work)
            expect(service_class).to_not receive(:perform_in)
            expect { service.call(*pass_arg_group, 'reschedule', false) }.to_not raise_error
          end
        end
      end
    end

    # Check that all Redis keys are deleted
    key_pattern = "#{described_class::KEY_PREFIX}*"
    expect(Services.redis.keys(key_pattern)).to be_empty
  end
end

describe Services::Base::UniquenessChecker do
  context 'when the service checks for uniqueness with the default args' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service_class) { UniqueService }
      let(:args)          { [] }
      let(:fail_args)     { [] }
    end
  end

  context 'when the service checks for uniqueness with custom args' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service_class) { UniqueWithCustomArgsService }
      let(:args)          { ['foo', 1, 'bar'] }
      let(:fail_args)     { [['foo', 1, 'pelle']] }
      let(:pass_args)     { [['foo', 2, 'bar']] }
    end
  end

  context 'when the service checks for uniqueness multiple times' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service_class) { UniqueMultipleService }
      let(:args)          { ['foo', 1, true] }
      let(:fail_args)     { args.map { |arg| [arg] } }
      let(:pass_args)     { [['pelle']] }
    end
  end

  context 'when the service does not check for uniqueness' do
    it_behaves_like 'checking the uniqueness properly' do
      let(:service_class) { NonUniqueService }
      let(:args)          { [] }
      let(:pass_args)     { [] }
    end
  end
end
