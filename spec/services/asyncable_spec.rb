require 'spec_helper'

describe Services::Asyncable do
  describe '#perform' do
    it 'calls `call` with the correct args' do
      expect { AsyncService.new.perform 'test', pelle: 'fant' }.to raise_error(%w(test baz fant).to_json)

      # If the `call` method arguments contains kwargs and the last argument to `perform` is a Hash,
      # it's keys should be symbolized. The reason is that the arguments to `perform` are serialized to
      # the database before Sidekiq picks them up, i.e. symbol keys are converted to strings.
      expect { AsyncService.new.perform 'test', 'pelle' => 'fant' }.to raise_error(%w(test baz fant).to_json)
    end
  end
end
