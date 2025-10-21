# frozen_string_literal: true

require "spec_helper"
require "kumi/core/types/value_objects"

RSpec.describe Kumi::Core::Types::ValueObjects do
  describe Kumi::Core::Types::ScalarType do
    it "creates a string scalar type" do
      type = Kumi::Core::Types::ScalarType.new(:string)
      expect(type.kind).to eq(:string)
      expect(type.to_s).to eq("string")
    end

    it "creates an integer scalar type" do
      type = Kumi::Core::Types::ScalarType.new(:integer)
      expect(type.kind).to eq(:integer)
      expect(type.to_s).to eq("integer")
    end

    it "creates a float scalar type" do
      type = Kumi::Core::Types::ScalarType.new(:float)
      expect(type.kind).to eq(:float)
      expect(type.to_s).to eq("float")
    end

    it "creates a boolean scalar type" do
      type = Kumi::Core::Types::ScalarType.new(:boolean)
      expect(type.kind).to eq(:boolean)
      expect(type.to_s).to eq("boolean")
    end

    it "creates a hash scalar type" do
      type = Kumi::Core::Types::ScalarType.new(:hash)
      expect(type.kind).to eq(:hash)
      expect(type.to_s).to eq("hash")
    end

    it "allows equality comparison" do
      type1 = Kumi::Core::Types::ScalarType.new(:string)
      type2 = Kumi::Core::Types::ScalarType.new(:string)
      expect(type1).to eq(type2)
    end

    it "distinguishes different scalar types" do
      string_type = Kumi::Core::Types::ScalarType.new(:string)
      integer_type = Kumi::Core::Types::ScalarType.new(:integer)
      expect(string_type).not_to eq(integer_type)
    end
  end

  describe Kumi::Core::Types::ArrayType do
    it "creates an array of scalars" do
      element_type = Kumi::Core::Types::ScalarType.new(:integer)
      array_type = Kumi::Core::Types::ArrayType.new(element_type)
      expect(array_type.element_type).to eq(element_type)
      expect(array_type.to_s).to eq("array<integer>")
    end

    it "creates an array of arrays" do
      inner_element = Kumi::Core::Types::ScalarType.new(:float)
      inner_array = Kumi::Core::Types::ArrayType.new(inner_element)
      outer_array = Kumi::Core::Types::ArrayType.new(inner_array)
      expect(outer_array.to_s).to eq("array<array<float>>")
    end

    it "allows equality comparison" do
      int_type = Kumi::Core::Types::ScalarType.new(:integer)
      array1 = Kumi::Core::Types::ArrayType.new(int_type)
      array2 = Kumi::Core::Types::ArrayType.new(int_type)
      expect(array1).to eq(array2)
    end

    it "distinguishes arrays of different element types" do
      int_type = Kumi::Core::Types::ScalarType.new(:integer)
      string_type = Kumi::Core::Types::ScalarType.new(:string)
      array_int = Kumi::Core::Types::ArrayType.new(int_type)
      array_string = Kumi::Core::Types::ArrayType.new(string_type)
      expect(array_int).not_to eq(array_string)
    end
  end

  describe Kumi::Core::Types::TupleType do
    it "creates a tuple with homogeneous types" do
      int_type = Kumi::Core::Types::ScalarType.new(:integer)
      tuple = Kumi::Core::Types::TupleType.new([int_type, int_type])
      expect(tuple.element_types.size).to eq(2)
      expect(tuple.to_s).to eq("tuple<integer, integer>")
    end

    it "creates a tuple with heterogeneous types" do
      int_type = Kumi::Core::Types::ScalarType.new(:integer)
      string_type = Kumi::Core::Types::ScalarType.new(:string)
      tuple = Kumi::Core::Types::TupleType.new([int_type, string_type])
      expect(tuple.element_types.size).to eq(2)
      expect(tuple.to_s).to eq("tuple<integer, string>")
    end

    it "allows equality comparison" do
      int_type = Kumi::Core::Types::ScalarType.new(:integer)
      tuple1 = Kumi::Core::Types::TupleType.new([int_type, int_type])
      tuple2 = Kumi::Core::Types::TupleType.new([int_type, int_type])
      expect(tuple1).to eq(tuple2)
    end

    it "distinguishes tuples with different element types" do
      int_type = Kumi::Core::Types::ScalarType.new(:integer)
      string_type = Kumi::Core::Types::ScalarType.new(:string)
      tuple1 = Kumi::Core::Types::TupleType.new([int_type, int_type])
      tuple2 = Kumi::Core::Types::TupleType.new([int_type, string_type])
      expect(tuple1).not_to eq(tuple2)
    end
  end

  describe "Type construction helpers" do
    it "provides a helper to create scalar types" do
      int_type = Kumi::Core::Types.scalar(:integer)
      expect(int_type).to be_a(Kumi::Core::Types::ScalarType)
      expect(int_type.to_s).to eq("integer")
    end

    it "provides a helper to create array types" do
      int_type = Kumi::Core::Types.scalar(:integer)
      array_type = Kumi::Core::Types.array(int_type)
      expect(array_type).to be_a(Kumi::Core::Types::ArrayType)
      expect(array_type.to_s).to eq("array<integer>")
    end

    it "provides a helper to create tuple types" do
      int_type = Kumi::Core::Types.scalar(:integer)
      string_type = Kumi::Core::Types.scalar(:string)
      tuple_type = Kumi::Core::Types.tuple([int_type, string_type])
      expect(tuple_type).to be_a(Kumi::Core::Types::TupleType)
      expect(tuple_type.to_s).to eq("tuple<integer, string>")
    end
  end

  describe "Type predicates" do
    it "identifies scalar types" do
      type = Kumi::Core::Types.scalar(:string)
      expect(type.scalar?).to be true
      expect(type.array?).to be false
      expect(type.tuple?).to be false
    end

    it "identifies array types" do
      int_type = Kumi::Core::Types.scalar(:integer)
      type = Kumi::Core::Types.array(int_type)
      expect(type.scalar?).to be false
      expect(type.array?).to be true
      expect(type.tuple?).to be false
    end

    it "identifies tuple types" do
      int_type = Kumi::Core::Types.scalar(:integer)
      type = Kumi::Core::Types.tuple([int_type])
      expect(type.scalar?).to be false
      expect(type.array?).to be false
      expect(type.tuple?).to be true
    end
  end
end
