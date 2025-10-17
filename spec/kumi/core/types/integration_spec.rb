# frozen_string_literal: true

require 'spec_helper'
require 'kumi/core/types/value_objects'

RSpec.describe 'NASTDimensionalAnalyzerPass with Type objects' do
  describe 'Type metadata propagation' do
    it 'validates that Types::Collection? recognizes type objects' do
      int_type = Kumi::Core::Types.scalar(:integer)
      array_type = Kumi::Core::Types.array(int_type)

      expect(Kumi::Core::Types.collection?(array_type)).to be true
      expect(Kumi::Core::Types.array?(array_type)).to be true
      expect(Kumi::Core::Types.collection?(int_type)).to be false
    end

    it 'validates tuple detection with type objects' do
      int_type = Kumi::Core::Types.scalar(:integer)
      string_type = Kumi::Core::Types.scalar(:string)
      tuple_type = Kumi::Core::Types.tuple([int_type, string_type])

      expect(Kumi::Core::Types.collection?(tuple_type)).to be true
      expect(Kumi::Core::Types.tuple?(tuple_type)).to be true
    end

    it 'preserves type information through Type object creation' do
      # Test that we can construct a nested type hierarchy
      int_type = Kumi::Core::Types.scalar(:integer)
      float_type = Kumi::Core::Types.scalar(:float)

      array_int = Kumi::Core::Types.array(int_type)
      array_float = Kumi::Core::Types.array(float_type)

      # These should be distinct
      expect(array_int).not_to eq(array_float)
      expect(array_int.to_s).to eq('array<integer>')
      expect(array_float.to_s).to eq('array<float>')
    end

    it 'handles deep nesting of types' do
      int_type = Kumi::Core::Types.scalar(:integer)
      array_int = Kumi::Core::Types.array(int_type)
      array_array_int = Kumi::Core::Types.array(array_int)

      expect(array_array_int.to_s).to eq('array<array<integer>>')
    end

    it 'supports type inspection and predicates' do
      int_type = Kumi::Core::Types.scalar(:integer)
      array_type = Kumi::Core::Types.array(int_type)

      expect(int_type.scalar?).to be true
      expect(int_type.array?).to be false
      expect(array_type.scalar?).to be false
      expect(array_type.array?).to be true
    end

    it 'compares types for equality' do
      int1 = Kumi::Core::Types.scalar(:integer)
      int2 = Kumi::Core::Types.scalar(:integer)
      string = Kumi::Core::Types.scalar(:string)

      expect(int1).to eq(int2)
      expect(int1).not_to eq(string)

      array1 = Kumi::Core::Types.array(int1)
      array2 = Kumi::Core::Types.array(int2)
      expect(array1).to eq(array2)
    end

    it 'uses types as hash keys (for metadata tables)' do
      int_type = Kumi::Core::Types.scalar(:integer)
      float_type = Kumi::Core::Types.scalar(:float)
      array_int = Kumi::Core::Types.array(int_type)

      metadata = {}
      metadata[int_type] = 'integer metadata'
      metadata[float_type] = 'float metadata'
      metadata[array_int] = 'array<integer> metadata'

      # Can retrieve using same type object
      expect(metadata[int_type]).to eq('integer metadata')
      expect(metadata[float_type]).to eq('float metadata')
      expect(metadata[array_int]).to eq('array<integer> metadata')

      # Can retrieve using equivalent type object
      int_equiv = Kumi::Core::Types.scalar(:integer)
      expect(metadata[int_equiv]).to eq('integer metadata')
    end
  end
end
