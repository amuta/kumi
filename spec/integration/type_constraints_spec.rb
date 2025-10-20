# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Type Constraints" do
  fixtures_dir = File.join(__dir__, "../fixtures/schemas/type_constraints")

  def compile_schema(schema_file)
    schema, = Kumi::Frontends.load(path: schema_file)
    Kumi::Analyzer.analyze!(schema)
  end

  describe "arithmetic constraints" do
    it "accepts numeric operations with correct types" do
      schema_file = File.join(fixtures_dir, "arithmetic_numeric.kumi")
      expect do
        compile_schema(schema_file)
      end.not_to raise_error
    end

    it "rejects string operands in addition" do
      schema_file = File.join(fixtures_dir, "error_string_plus.kumi")
      expect do
        compile_schema(schema_file)
      end.to raise_error(Kumi::Errors::Error)
    end

    it "rejects string * float" do
      schema_file = File.join(fixtures_dir, "error_string_multiply_float.kumi")
      expect do
        compile_schema(schema_file)
      end.to raise_error(Kumi::Errors::Error)
    end
  end

  describe "comparison constraints" do
    it "accepts orderable operations with correct types" do
      schema_file = File.join(fixtures_dir, "comparisons_orderable.kumi")
      expect do
        compile_schema(schema_file)
      end.not_to raise_error
    end

    it "rejects boolean operands in > comparison" do
      schema_file = File.join(fixtures_dir, "error_boolean_gt.kumi")
      expect do
        compile_schema(schema_file)
      end.to raise_error(Kumi::Errors::Error)
    end
  end

  describe "boolean constraints" do
    it "accepts boolean operations with correct types" do
      schema_file = File.join(fixtures_dir, "boolean_ops.kumi")
      expect do
        compile_schema(schema_file)
      end.not_to raise_error
    end

    it "rejects integer operands in & operator" do
      schema_file = File.join(fixtures_dir, "error_integer_and.kumi")
      expect do
        compile_schema(schema_file)
      end.to raise_error(Kumi::Errors::Error)
    end
  end

  describe "string multiplication" do
    it "accepts string * integer" do
      schema_file = File.join(fixtures_dir, "string_multiply.kumi")
      expect do
        compile_schema(schema_file)
      end.not_to raise_error
    end
  end
end
