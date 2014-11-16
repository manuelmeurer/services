require 'spec_helper'

describe Services::BaseFinder do
  it 'does not log start and end' do
    expect { Services::Models::BaseFind.call }.to_not change { @logs }
  end
end
