require 'spec_helper'

describe Services::BaseFinder do
  include_context 'capture logs'

  it 'has call logging disabled by default' do
    expect(Services::Models::BaseFind.call_logging_disabled).to eq(true)
    expect { Services::Models::BaseFind.call }.to_not change { logs }
  end
end
