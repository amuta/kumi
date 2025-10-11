# frozen_string_literal: true

RSpec.describe Kumi::Schema do
  let(:test_class) do
    Class.new do
      extend Kumi::Schema
    end
  end

  describe "#schema" do
    it "defines a schema with input and trait" do
      test_class.schema do
        input do
          integer :age
        end

        trait :adult, (input.age >= 18)
      end

      expect(test_class.__kumi_syntax_tree__).not_to be_nil
      expect(test_class.__kumi_compiled_module__).not_to be_nil
    end

    it "stores syntax tree after schema definition" do
      test_class.schema do
        input { integer :x }
        value :y, input.x * 2
      end

      tree = test_class.__kumi_syntax_tree__
      expect(tree).to be_a(Kumi::Syntax::Root)
    end
  end

  describe "#from" do
    before do
      test_class.schema do
        input do
          integer :age
          float :score
        end

        trait :adult, (input.age >= 18)
        value :doubled_score, input.score * 2
      end
    end

    it "executes schema with input data" do
      result = test_class.from(age: 25, score: 50.0)

      expect(result[:adult]).to be true
      expect(result[:doubled_score]).to eq(100.0)
    end

    it "handles different input values" do
      result = test_class.from(age: 15, score: 30.0)

      expect(result[:adult]).to be false
      expect(result[:doubled_score]).to eq(60.0)
    end

    it "works with symbol keys" do
      result = test_class.from({ age: 30, score: 75.0 })
      expect(result[:adult]).to be true
    end

    it "works with string keys" do
      result = test_class.from({ "age" => 30, "score" => 75.0 })
      expect(result[:adult]).to be true
    end
  end

  describe "#runner" do
    before do
      test_class.schema do
        input { integer :x }
        value :y, input.x * 2
      end
    end

    it "returns a runner with empty input" do
      runner = test_class.runner
      expect(runner).to respond_to(:[])
    end
  end

  describe "#schema_metadata" do
    before do
      test_class.schema do
        input do
          integer :age, domain: 18..65
          float :balance
        end

        trait :adult, (input.age >= 18)
        value :doubled_balance, input.balance * 2
      end
    end

    it "returns metadata object" do
      metadata = test_class.schema_metadata
      expect(metadata).to be_a(Kumi::SchemaMetadata)
    end

    it "provides input metadata" do
      metadata = test_class.schema_metadata
      expect(metadata.inputs).to have_key(:age)
      expect(metadata.inputs).to have_key(:balance)
    end

    it "provides trait metadata" do
      metadata = test_class.schema_metadata
      expect(metadata.traits).to have_key(:adult)
      expect(metadata.traits[:adult][:type]).to eq(:boolean)
    end

    it "provides value metadata" do
      metadata = test_class.schema_metadata
      expect(metadata.values).to have_key(:doubled_balance)
    end
  end

  describe "#build_syntax_tree" do
    it "builds syntax tree without compiling" do
      test_class.build_syntax_tree do
        input { integer :x }
        value :y, input.x * 2
      end

      expect(test_class.__kumi_syntax_tree__).not_to be_nil
      expect(test_class.__kumi_compiled_module__).to be_nil
    end
  end

  describe "#write_source" do
    let(:output_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(output_dir)
    end

    context "with valid schema" do
      before do
        test_class.schema do
          input do
            integer :age
          end

          trait :adult, (input.age >= 18)
        end
      end

      it "writes ruby code to file" do
        output_path = File.join(output_dir, "schema.rb")
        result = test_class.write_source(output_path, platform: :ruby)

        expect(result).to eq(output_path)
        expect(File.exist?(output_path)).to be true
        content = File.read(output_path)
        expect(content).to include("module Kumi::Compiled::")
        expect(content).to include("def _adult")
      end

      it "writes javascript code to file" do
        output_path = File.join(output_dir, "schema.mjs")
        result = test_class.write_source(output_path, platform: :javascript)

        expect(result).to eq(output_path)
        expect(File.exist?(output_path)).to be true
        content = File.read(output_path)
        expect(content).to include("export")
      end

      it "creates parent directories if they don't exist" do
        output_path = File.join(output_dir, "nested", "deep", "schema.rb")
        test_class.write_source(output_path, platform: :ruby)

        expect(File.exist?(output_path)).to be true
      end

      it "defaults to ruby platform" do
        output_path = File.join(output_dir, "schema.rb")
        test_class.write_source(output_path)

        content = File.read(output_path)
        expect(content).to include("module Kumi::Compiled::")
      end
    end

    context "with invalid platform" do
      before do
        test_class.schema do
          input { integer :age }
        end
      end

      it "raises ArgumentError for invalid platform" do
        output_path = File.join(output_dir, "schema.txt")
        expect do
          test_class.write_source(output_path, platform: :python)
        end.to raise_error(ArgumentError, "platform must be :ruby or :javascript")
      end
    end

    context "without schema defined" do
      it "raises error when no schema is defined" do
        output_path = File.join(output_dir, "schema.rb")
        expect do
          test_class.write_source(output_path)
        end.to raise_error("No schema defined")
      end
    end
  end

  describe "compilation caching" do
    before do
      test_class.schema do
        input { integer :x }
        value :y, input.x * 2
      end
    end

    it "compiles once and reuses for multiple from calls" do
      result1 = test_class.from(x: 5)
      result2 = test_class.from(x: 10)

      expect(result1[:y]).to eq(10)
      expect(result2[:y]).to eq(20)
    end
  end

  describe "complex schema execution" do
    before do
      test_class.schema do
        input do
          float :amount
          string :type
          integer :years
        end

        trait :high_amount, (input.amount > 100.0)
        trait :premium, (input.type == "premium")

        value :discount do
          on high_amount, premium, 0.25
          on premium, 0.15
          on high_amount, 0.10
          base 0.0
        end

        value :multiplier, fn(:subtract, 1.0, discount)
        value :final_amount, input.amount * multiplier
      end
    end

    it "handles cascade logic correctly" do
      result = test_class.from(amount: 150.0, type: "premium", years: 5)
      expect(result[:high_amount]).to be true
      expect(result[:premium]).to be true
      expect(result[:discount]).to eq(0.25)
      expect(result[:final_amount]).to eq(112.5)
    end

    it "handles cascade with partial matches" do
      result = test_class.from(amount: 50.0, type: "premium", years: 2)
      expect(result[:high_amount]).to be false
      expect(result[:premium]).to be true
      expect(result[:discount]).to eq(0.15)
      expect(result[:final_amount]).to eq(42.5)
    end

    it "handles cascade with no matches" do
      result = test_class.from(amount: 50.0, type: "basic", years: 1)
      expect(result[:discount]).to eq(0.0)
      expect(result[:final_amount]).to eq(50.0)
    end
  end

  describe "array operations" do
    let(:array_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            array :numbers, elem: { type: :float }
          end

          value :total, fn(:sum, input.numbers)
          value :count, fn(:size, input.numbers)
          value :average, total / count
        end
      end
    end

    it "handles array inputs and operations" do
      result = array_schema.from(numbers: [1.0, 2.0, 3.0, 4.0, 5.0])

      expect(result[:total]).to eq(15.0)
      expect(result[:count]).to eq(5)
      expect(result[:average]).to eq(3.0)
    end

    it "handles empty arrays" do
      result = array_schema.from(numbers: [])

      expect(result[:total]).to eq(0.0)
      expect(result[:count]).to eq(0)
    end
  end
end
