require 'spec_helper'

describe Services do
  context 'configuration' do
    describe 'logger' do
      it 'uses the null logger by default' do
        expect(Services.configuration.logger).to be_a(Services::Logger::Null)
      end
    end
  end
end
