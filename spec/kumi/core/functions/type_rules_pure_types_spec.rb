# frozen_string_literal: true

require 'spec_helper'
require 'kumi/core/functions/type_rules'
require 'kumi/core/types/value_objects'

RSpec.describe Kumi::Core::Functions::TypeRules do
  describe 'Pure Type object handling (no legacy strings)' do
    let(:int_type) { Kumi::Core::Types.scalar(:integer) }
    let(:float_type) { Kumi::Core::Types.scalar(:float) }
    let(:string_type) { Kumi::Core::Types.scalar(:string) }

    describe '#array_type with Type objects' do
      it 'creates ArrayType from ScalarType' do
        result = described_class.array_type(int_type)
        expect(result).to be_a(Kumi::Core::Types::ArrayType)
        expect(result.element_type).to eq(int_type)
      end

      it 'works with nested types' do
        array_int = Kumi::Core::Types.array(int_type)
        result = described_class.array_type(array_int)
        expect(result).to be_a(Kumi::Core::Types::ArrayType)
        expect(result.to_s).to eq('array<array<integer>>')
      end
    end

    describe '#tuple_type with Type objects' do
      it 'creates TupleType from Type objects' do
        result = described_class.tuple_type(int_type, float_type)
        expect(result).to be_a(Kumi::Core::Types::TupleType)
        expect(result.element_types).to eq([int_type, float_type])
      end

      it 'handles single element tuples' do
        result = described_class.tuple_type(string_type)
        expect(result).to be_a(Kumi::Core::Types::TupleType)
        expect(result.to_s).to eq('tuple<string>')
      end
    end

    describe '#element_type_of with Type objects' do
      it 'extracts element type from ArrayType' do
        array_type = Kumi::Core::Types.array(int_type)
        result = described_class.element_type_of(array_type)
        expect(result).to eq(int_type)
      end

      it 'extracts promoted type from TupleType' do
        int_t = Kumi::Core::Types.scalar(:integer)
        float_t = Kumi::Core::Types.scalar(:float)
        tuple_type = Kumi::Core::Types.tuple([int_t, float_t])
        result = described_class.element_type_of(tuple_type)
        # Promotion should result in float (higher precision)
        expect(result).to eq(float_t)
      end

      it 'returns scalar type unchanged' do
        result = described_class.element_type_of(int_type)
        expect(result).to eq(int_type)
      end
    end

    describe '#promote_types with Type objects' do
      it 'promotes integer and float to float' do
        result = described_class.promote_types(int_type, float_type)
        expect(result).to eq(float_type)
      end

      it 'returns single type if only one provided' do
        result = described_class.promote_types(int_type)
        expect(result).to eq(int_type)
      end

      it 'handles multiple identical types' do
        result = described_class.promote_types(int_type, int_type, int_type)
        expect(result).to eq(int_type)
      end
    end

    describe '#compile_dtype_rule with Type return values' do
      it 'compiles promote rule to return Type objects' do
        rule = described_class.compile_dtype_rule('promote(a, b)', [:a, :b])
        result = rule.call({ a: int_type, b: float_type })
        expect(result).to eq(float_type)
      end

      it 'compiles same_as rule to return Type objects' do
        rule = described_class.compile_dtype_rule('same_as(a)', [:a])
        result = rule.call({ a: int_type })
        expect(result).to eq(int_type)
      end

      it 'compiles array rule to return ArrayType' do
        rule = described_class.compile_dtype_rule('array(integer)', [])
        result = rule.call({})
        expect(result).to be_a(Kumi::Core::Types::ArrayType)
      end

      it 'compiles element_of rule to extract from ArrayType' do
        array_type = Kumi::Core::Types.array(int_type)
        rule = described_class.compile_dtype_rule('element_of(arr)', [:arr])
        result = rule.call({ arr: array_type })
        expect(result).to eq(int_type)
      end

      it 'returns scalar Type for constant rules' do
        rule = described_class.compile_dtype_rule('integer', [])
        result = rule.call({})
        expect(result).to be_a(Kumi::Core::Types::ScalarType)
        expect(result.kind).to eq(:integer)
      end
    end

    describe 'type rules return Type objects not symbols' do
      it 'promote_types returns Type objects' do
        result = described_class.promote_types(int_type, float_type)
        expect(result).to be_a(Kumi::Core::Types::Type)
      end

      it 'array_type returns ArrayType' do
        result = described_class.array_type(int_type)
        expect(result).to be_a(Kumi::Core::Types::ArrayType)
      end

      it 'tuple_type returns TupleType' do
        result = described_class.tuple_type(int_type, float_type)
        expect(result).to be_a(Kumi::Core::Types::TupleType)
      end
    end

    describe 'Builder API (Direct Type Construction)' do
      describe '#build_same_as' do
        it 'builds rule that returns parameter type' do
          rule = described_class.build_same_as(:value)
          result = rule.call({ value: int_type })
          expect(result).to eq(int_type)
        end

        it 'works with different parameter names' do
          rule = described_class.build_same_as(:source_value)
          result = rule.call({ source_value: float_type })
          expect(result).to eq(float_type)
        end
      end

      describe '#build_promote' do
        it 'builds rule that promotes multiple parameters' do
          rule = described_class.build_promote(:a, :b)
          result = rule.call({ a: int_type, b: float_type })
          expect(result).to eq(float_type)
        end

        it 'handles single parameter' do
          rule = described_class.build_promote(:x)
          result = rule.call({ x: string_type })
          expect(result).to eq(string_type)
        end
      end

      describe '#build_element_of' do
        it 'builds rule that extracts element type from ArrayType' do
          rule = described_class.build_element_of(:collection)
          array_type = Kumi::Core::Types.array(int_type)
          result = rule.call({ collection: array_type })
          expect(result).to eq(int_type)
        end

        it 'extracts promoted type from TupleType' do
          rule = described_class.build_element_of(:tuple_param)
          tuple_type = Kumi::Core::Types.tuple([int_type, float_type])
          result = rule.call({ tuple_param: tuple_type })
          expect(result).to eq(float_type)
        end
      end

      describe '#build_unify' do
        it 'builds rule that unifies two parameters' do
          rule = described_class.build_unify(:left, :right)
          result = rule.call({ left: int_type, right: float_type })
          expect(result).to eq(float_type)
        end

        it 'returns first type when both are same' do
          rule = described_class.build_unify(:a, :b)
          result = rule.call({ a: int_type, b: int_type })
          expect(result).to eq(int_type)
        end
      end

      describe '#build_common_type' do
        it 'builds rule for common type among elements' do
          rule = described_class.build_common_type(:elements)
          result = rule.call({ elements: [int_type, float_type] })
          expect(result).to eq(float_type)
        end
      end

      describe '#build_array' do
        it 'builds rule with constant element type' do
          rule = described_class.build_array(:integer)
          result = rule.call({})
          expect(result).to be_a(Kumi::Core::Types::ArrayType)
          expect(result.element_type.kind).to eq(:integer)
        end

        it 'builds rule with parameter reference' do
          rule = described_class.build_array(:elem_type)
          result = rule.call({ elem_type: int_type })
          expect(result).to be_a(Kumi::Core::Types::ArrayType)
          expect(result.element_type).to eq(int_type)
        end
      end

      describe '#build_tuple' do
        it 'builds rule with constant element types' do
          rule = described_class.build_tuple(:integer, :float)
          result = rule.call({})
          expect(result).to be_a(Kumi::Core::Types::TupleType)
          expect(result.element_types.map(&:kind)).to eq([:integer, :float])
        end

        it 'builds rule with parameter reference to types array' do
          rule = described_class.build_tuple(:types)
          result = rule.call({ types: [int_type, string_type] })
          expect(result).to be_a(Kumi::Core::Types::TupleType)
          expect(result.element_types).to eq([int_type, string_type])
        end
      end

      describe '#build_scalar' do
        it 'builds rule for scalar type kind' do
          rule = described_class.build_scalar(:integer)
          result = rule.call({})
          expect(result).to be_a(Kumi::Core::Types::ScalarType)
          expect(result.kind).to eq(:integer)
        end

        it 'works with different scalar kinds' do
          [:string, :float, :boolean].each do |kind|
            rule = described_class.build_scalar(kind)
            result = rule.call({})
            expect(result.kind).to eq(kind)
          end
        end
      end
    end
  end
end
