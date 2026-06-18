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
        expect(content).to include("def self._adult(input)")
      end

      it "writes javascript code to file" do
        output_path = File.join(output_dir, "schema.mjs")
        result = test_class.write_source(output_path, platform: :javascript)

        expect(result).to eq(output_path)
        expect(File.exist?(output_path)).to be true
        content = File.read(output_path)
        expect(content).to include("export")
      end

      it "does not emit streaming javascript exports by default" do
        output_path = File.join(output_dir, "schema.mjs")
        test_class.write_source(output_path, platform: :javascript)

        content = File.read(output_path)
        expect(content).not_to include("_adult_stream")
      end

      it "emits and runs streaming javascript exports when requested" do
        streaming_schema = Class.new do
          extend Kumi::Schema
        end

        streaming_schema.schema do
          codegen streaming: true

          input do
            array :items do
              hash :item do
                float :price
              end
            end
            float :tax_rate
          end

          value :gross_prices, input.items.item.price * (input.tax_rate + 1.0)
          value :tax_multiplier, input.tax_rate + 1.0
        end

        output_path = File.join(output_dir, "streaming_schema.mjs")
        streaming_schema.write_source(output_path, platform: :javascript)
        content = File.read(output_path)

        expect(content).to include("export function _gross_prices(input)")
        expect(content).to include("export function _gross_prices_stream(input, target = {})")
        expect(content).to include("export function _tax_multiplier_stream(input, target = {})")
        expect(content).not_to include("Array.isArray")
        expect(content).not_to include("ArrayBuffer.isView")
        expect(content).not_to include("TypeError")
        expect(content).not_to include("RangeError")

        runner = <<~JS
          const mod = await import(process.argv[1]);
          const input = { items: [{ price: 10.0 }, { price: 20.0 }], tax_rate: 0.1 };
          const target = { gross_prices: [999] };
          const normal = mod._gross_prices(input);
          const streamed = mod._gross_prices_stream(input, target);
          const taxMultiplier = mod._tax_multiplier_stream(input, target);
          console.log(JSON.stringify({
            normal,
            streamed,
            target,
            sameArray: streamed === target.gross_prices,
            taxMultiplier,
          }));
        JS

        stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", runner, output_path)
        expect(status).to be_success, stderr

        result = JSON.parse(stdout)
        expect(result["normal"]).to eq([11.0, 22.0])
        expect(result["streamed"]).to eq([11.0, 22.0])
        expect(result["target"]["gross_prices"]).to eq([11.0, 22.0])
        expect(result["sameArray"]).to be true
        expect(result["taxMultiplier"]).to eq(1.1)
        expect(result["target"]["tax_multiplier"]).to eq(1.1)
      end

      it "reuses record elements and truncates streaming outputs" do
        streaming_schema = Class.new do
          extend Kumi::Schema
        end

        streaming_schema.schema do
          codegen streaming: true

          input do
            array :bodies do
              hash :body do
                float :x
              end
            end
            float :dt
          end

          let :x, input.bodies.body.x
          value :next_bodies, { x: x + input.dt }
        end

        output_path = File.join(output_dir, "record_streaming.mjs")
        streaming_schema.write_source(output_path, platform: :javascript)

        runner = <<~JS
          const mod = await import(process.argv[1]);
          const input = { bodies: [{ x: 1 }, { x: 2 }, { x: 3 }], dt: 0.5 };
          const target = {};
          mod._next_bodies_stream(input, target);
          const refs = target.next_bodies.map((o) => o);
          const first = target.next_bodies.map((o) => o.x);
          mod._next_bodies_stream({ ...input, dt: 1.0 }, target);
          const reused = target.next_bodies.every((o, i) => o === refs[i]);
          const second = target.next_bodies.map((o) => o.x);
          mod._next_bodies_stream({ bodies: [{ x: 9 }], dt: 0 }, target);
          const truncated = target.next_bodies.length;
          console.log(JSON.stringify({ first, second, reused, truncated }));
        JS

        stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", runner, output_path)
        expect(status).to be_success, stderr

        result = JSON.parse(stdout)
        expect(result["first"]).to eq([1.5, 2.5, 3.5])
        expect(result["second"]).to eq([2.0, 3.0, 4.0])
        expect(result["reused"]).to be true
        expect(result["truncated"]).to eq(1)
      end

      it "streams nested array outputs with row and record reuse matching normal output" do
        streaming_schema = Class.new do
          extend Kumi::Schema
        end

        streaming_schema.schema do
          codegen streaming: true

          input do
            array :rows do
              array :col do
                hash :cell do
                  float :a
                end
              end
            end
            float :k
          end

          let :a, input.rows.col.cell.a
          value :next_cells, { a: a * input.k }
        end

        output_path = File.join(output_dir, "nested_streaming.mjs")
        streaming_schema.write_source(output_path, platform: :javascript)

        runner = <<~JS
          const mod = await import(process.argv[1]);
          const mk = () => [[{ a: 1 }, { a: 2 }], [{ a: 3 }, { a: 4 }]];
          const input = { rows: mk(), k: 2 };
          const target = {};
          const streamed = mod._next_cells_stream(input, target);
          const streamedJson = JSON.stringify(streamed);
          const normal = mod._next_cells(input);
          const rowRefs = target.next_cells.map((r) => r);
          const cellRefs = target.next_cells.map((r) => r.map((c) => c));
          mod._next_cells_stream({ rows: mk(), k: 3 }, target);
          const rowsReused = target.next_cells.every((r, i) => r === rowRefs[i]);
          const cellsReused = target.next_cells.every((r, i) => r.every((c, j) => c === cellRefs[i][j]));
          console.log(JSON.stringify({
            match: streamedJson === JSON.stringify(normal),
            second: target.next_cells.map((r) => r.map((c) => c.a)),
            rowsReused,
            cellsReused
          }));
        JS

        stdout, stderr, status = Open3.capture3("node", "--input-type=module", "-e", runner, output_path)
        expect(status).to be_success, stderr

        result = JSON.parse(stdout)
        expect(result["match"]).to be true
        expect(result["second"]).to eq([[3.0, 6.0], [9.0, 12.0]])
        expect(result["rowsReused"]).to be true
        expect(result["cellsReused"]).to be true
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
        end.to raise_error(Kumi::Core::Errors::ConfigurationError, /no schema defined/)
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
  end
end
