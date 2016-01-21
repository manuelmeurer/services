require 'spec_helper'

describe Services::Base do
  let(:model_ids)             { (1..5).to_a.shuffle }
  let(:model_objects)         { model_ids.map { |id| Model.new(id) } }
  let(:model_ids_and_objects) { model_ids[0..2] + model_objects[3..-1] }

  describe '#find_objects' do
    context 'when passing in objects' do
      it 'returns the same objects' do
        expect(Services::Models::FindObjectsTest.call(model_objects)).to match_array(model_objects)
      end
    end

    context 'when passing in IDs' do
      it 'returns the objects for the IDs' do
        expect(Services::Models::FindObjectsTest.call(model_ids)).to match_array(model_objects)
      end
    end

    context 'when passing in objects and IDs' do
      it 'returns the objects plus the objects for the IDs' do
        expect(Services::Models::FindObjectsTest.call(model_ids_and_objects)).to match_array(model_objects)
      end
    end

    context 'when passing in a single object or ID' do
      it 'returns an array containing the object' do
        [model_ids.first, model_objects.first].each do |id_or_object|
          expect(Services::Models::FindObjectsTest.call(id_or_object)).to match_array([model_objects.first])
        end
      end
    end
  end

  describe '#find_object' do
    context 'when passing in a single object or ID' do
      it 'returns the object' do
        [model_ids.first, model_objects.first].each do |id_or_object|
          expect(Services::Models::FindObjectTest.call(id_or_object)).to eq(model_objects.first)
        end
      end
    end

    context 'when passing in something else than a single object or ID' do
      it 'raises an error' do
        [%w(foo bar), nil, Object.new].each do |object|
          expect { Services::Models::FindObjectTest.call(object) }.to raise_error(Services::Models::FindObjectTest::Error)
        end
      end
    end
  end

  describe '#find_ids' do
    context 'when passing in objects' do
      it 'returns the IDs for the objects' do
        expect(Services::Models::FindIdsTest.call(model_objects)).to match_array(model_ids)
      end
    end

    context 'when passing in IDs' do
      it 'returns the same IDs' do
        expect(Services::Models::FindIdsTest.call(model_ids)).to match_array(model_ids)
      end
    end

    context 'when passing in objects and IDs' do
      it 'returns the IDs for the objects plus the passed in IDs' do
        expect(Services::Models::FindIdsTest.call(model_ids_and_objects)).to match_array(model_ids)
      end
    end

    context 'when passing in a single object or ID' do
      it 'returns an array containing the ID' do
        [model_ids.first, model_objects.first].each do |id_or_object|
          expect(Services::Models::FindIdsTest.call(id_or_object)).to match_array([model_ids.first])
        end
      end
    end
  end

  describe '#find_id' do
    context 'when passing in a single object or ID' do
      it 'returns the ID' do
        [model_ids.first, model_objects.first].each do |id_or_object|
          expect(Services::Models::FindIdTest.call(id_or_object)).to eq(model_ids.first)
        end
      end
    end

    context 'when passing in something else than a single object or ID' do
      it 'raises an error' do
        [%w(foo bar), nil, Object.new].each do |object|
          expect { Services::Models::FindIdTest.call(object) }.to raise_error(Services::Models::FindIdTest::Error)
        end
      end
    end
  end
end
