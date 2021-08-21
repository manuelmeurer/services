require 'spec_helper'
require SUPPORT_DIR.join('activerecord_models_and_services')

describe Services::Query do
  include_context 'capture logs'

  it 'has call logging disabled by default' do
    expect { Services::Posts::Find.call [] }.to_not change { logs }
  end

  describe '.convert_condition_objects_to_ids' do
    let(:comment) { Comment.create! }
    let(:comments) { (1..3).map { Comment.create! } }

    it 'converts condition objects to ids' do
      {
        comment     => comment.id,
        comments    => comments.map(&:id),
        Comment.all => Comment.all.map { |comment| { id: comment.id } }
      }.each do |condition_before, condition_after|
        expect { Services::Posts::FindRaiseConditions.call [], comment: condition_before }.to raise_error({ comment_id: condition_after }.to_json)
      end
    end
  end

  describe 'calling without IDs parameter' do
    let(:post) { Post.create! title: 'Superpost!' }

    it 'works' do
      expect(Services::Posts::Find.call title: post.title).to eq([post])
    end
  end
end
