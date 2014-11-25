require 'spec_helper'

describe Services::BaseFinder do
  include_context 'capture logs'

  let(:base_find) { Services::Models::BaseFind }

  it 'has call logging disabled by default' do
    expect(base_find.call_logging_disabled).to eq(true)
    expect { base_find.call }.to_not change { logs }
  end
end
