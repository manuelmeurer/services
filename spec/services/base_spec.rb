require 'spec_helper'

describe Services::Base do
  let(:model_objects) { (1..5).to_a.shuffle.map { |id| Model.new(id) } }

  describe '#find_objects' do
    context 'when passing in objects' do
      it 'returns the same objects' do
        expect(Services::Models::FindObjectsTest.call(model_objects)).to eq(model_objects)
      end
    end

    context 'when passing in IDs' do
      it 'returns the objects for the IDs' do
        expect(Services::Models::FindObjectsTest.call(model_objects.map(&:id))).to eq(model_objects)
      end
    end

    context 'when passing in objects and IDs' do
      it 'returns the objects plus the objects for the IDs' do
        objects_as_objects, objects_as_ids = model_objects.partition do |object|
          rand(2) == 1
        end

        objects_and_ids = objects_as_objects + objects_as_ids.map(&:id)
        only_objects = objects_as_objects + objects_as_ids

        expect(Services::Models::FindObjectsTest.call(objects_and_ids)).to eq(only_objects)
      end
    end

    context 'when passing in a single object or ID' do
      it 'returns an array containing the object' do
        object = model_objects.sample
        [object.id, object].each do |id_or_object|
          expect(Services::Models::FindObjectsTest.call(id_or_object)).to eq([object])
        end
      end
    end
  end

  describe '#find_object' do
    context 'when passing in a single object or ID' do
      it 'returns the object' do
        object = model_objects.sample
        [object.id, object].each do |id_or_object|
          expect(Services::Models::FindObjectTest.call(id_or_object)).to eq(object)
        end
      end
    end

    context 'when passing in something else than a single object or ID' do
      it 'raises an error' do
        [%w(foo bar), nil, Object.new].each do |object|
          expect { Services::Models::FindObjectTest.call(object) }.to raise_error
        end
      end
    end
  end
end
