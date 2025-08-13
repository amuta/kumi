# frozen_string_literal: true

require_relative "../support/analyzer_state_helper"

RSpec.describe "AccessPlanner + AccessBuilder edge cases" do
  include AnalyzerStateHelper

  def build_accessors_from_schema(**opts, &schema_block)
    input_metadata = get_analyzer_state(:input_metadata, &schema_block)
    plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata, opts)
    Kumi::Core::Compiler::AccessBuilder.build(plans)
  end

  context "depth=0 (:read)" do
    it "fetches scalar leaves with on_missing policies" do
      acc = build_accessors_from_schema(on_missing: :nil) do
        input do
          string :name
        end
      end
      data = { "name" => "Ada" }
      expect(acc["name:read"].call(data)).to eq("Ada")
      expect(acc["name:read"].call({})).to eq(nil)
    end

    it "returns hash leaves intact" do
      acc = build_accessors_from_schema do
        input do
          string :first
        end
      end
      data = { "first" => "Linus" }
      expect(acc["first:read"].call(data)).to be("Linus")
    end

    it "does not emit :each_indexed/:materialize/:ravel for depth=0" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          string :name
        end
      end
      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)

      expect(plans["name"].map(&:mode)).to contain_exactly(:read)
    end
  end

  context "key_policy" do
    it "honors :string / :symbol / :indifferent in all modes" do
      schema_block = proc do
        input do
          array :regions do
            float :tax_rate
          end
        end
      end

      data = { "regions" => [{ "tax_rate" => 0.2 }, { tax_rate: 0.15 }] }

      acc_ind = build_accessors_from_schema(on_missing: :skip, key_policy: :indifferent, &schema_block)
      acc_str = build_accessors_from_schema(on_missing: :skip, key_policy: :string, &schema_block)
      acc_sym = build_accessors_from_schema(on_missing: :skip, key_policy: :symbol, &schema_block)

      expect(acc_ind["regions.tax_rate:materialize"].call(data)).to eq([0.2, 0.15])
      expect(acc_str["regions.tax_rate:materialize"].call(data)).to eq([0.2, nil])   # second is symbol-keyed
      expect(acc_sym["regions.tax_rate:materialize"].call(data)).to eq([nil, 0.15])  # first is string-keyed
    end
  end

  context "on_missing policy" do
    let(:schema_block) do
      proc do
        input do
          array :regions do
            array :offices do
              float :revenue
            end
          end
        end
      end
    end

    it ":ravel with :nil yields nils; with :skip drops elements" do
      data = { "regions" => [{ "offices" => [{}, { "revenue" => 2.0 }] }, { "offices" => [] }] }
      acc_nil  = build_accessors_from_schema(on_missing: :nil, &schema_block)
      acc_skip = build_accessors_from_schema(on_missing: :skip, &schema_block)

      expect(acc_nil["regions.offices.revenue:ravel"].call(data)).to eq([nil, 2.0]) # two leaf positions
      expect(acc_skip["regions.offices.revenue:ravel"].call(data)).to eq([2.0]) # missing leaf skipped
    end

    it ":materialize keeps outer shape; :skip returns [] for missing arrays" do
      data = { "regions" => [{ "offices" => nil }, { "offices" => [{ "revenue" => 1.0 }] }] }
      acc_nil  = build_accessors_from_schema(on_missing: :nil, &schema_block)
      acc_skip = build_accessors_from_schema(on_missing: :skip, &schema_block)

      expect(acc_nil["regions.offices.revenue:materialize"].call(data)).to eq([nil, [1.0]])
      expect(acc_skip["regions.offices.revenue:materialize"].call(data)).to eq([[], [1.0]])
    end

    it "raises on :error for missing keys/arrays with clear messages" do
      data = { "regions" => [{}, { "offices" => [{ "revenue" => 1.0 }] }] }
      acc = build_accessors_from_schema(on_missing: :error, &schema_block)
      expect do
        acc["regions.offices.revenue:ravel"].call(data)
      end.to raise_error(KeyError, /Missing key 'offices'.*regions\.offices\.revenue/i)
    end
  end

  context "type violations" do
    it "TypeError when expecting Hash" do
      acc = build_accessors_from_schema do
        input do
          array :regions do
            float :tax_rate
          end
        end
      end
      data = { "regions" => ["not a hash"] }
      expect do
        acc["regions.tax_rate:materialize"].call(data)
      end.to raise_error(TypeError, /Expected Hash/)
    end

    it "TypeError when expecting Array" do
      acc = build_accessors_from_schema do
        input do
          array :regions do
            float :tax_rate
          end
        end
      end
      data = { "regions" => { "tax_rate" => 0.2 } }
      expect do
        acc["regions.tax_rate:ravel"].call(data)
      end.to raise_error(TypeError, /Expected Array/)
    end
  end

  context "enumeration semantics" do
    it ":each_indexed order matches DFS left-to-right and aligns with :materialize" do
      acc = build_accessors_from_schema do
        input do
          array :regions do
            array :offices do
              float :rev
            end
          end
        end
      end
      data = { "regions" => [{ "offices" => [{ "rev" => 1.0 }, { "rev" => 2.0 }] }, { "offices" => [{ "rev" => 3.0 }] }] }

      mat = acc["regions.offices.rev:materialize"].call(data)
      enum = acc["regions.offices.rev:each_indexed"].call(data).to_a

      expect(enum.map(&:first)).to eq([1.0, 2.0, 3.0])
      expect(enum.map(&:last)).to eq([[0, 0], [0, 1], [1, 0]])
      expect(mat.flatten).to eq(enum.map(&:first))
    end

    it ":each_indexed yields two args to block" do
      acc = build_accessors_from_schema do
        input do
          array :regions do
            float :tax_rate
          end
        end
      end
      data = { "regions" => [{ "tax_rate" => 0.2 }, { "tax_rate" => 0.15 }] }

      seen = []
      acc["regions.tax_rate:each_indexed"].call(data) { |v, idx| seen << [v, idx] }
      expect(seen).to eq([[0.2, [0]], [0.15, [1]]])
    end
  end

  context "leaf as object" do
    it "returns hashes at the endpoint" do
      acc = build_accessors_from_schema do
        input do
          array :regions do
            string :code
          end
        end
      end
      data = { "regions" => [{ "code" => "NE" }, { "code" => "SW" }] }

      expect(acc["regions.code:materialize"].call(data)).to eq(%w[NE SW])
      expect(acc["regions.code:ravel"].call(data)).to eq(%w[NE SW])
      enum = acc["regions.code:each_indexed"].call(data).to_a
      expect(enum).to eq([["NE", [0]], ["SW", [1]]])
    end
  end
end
