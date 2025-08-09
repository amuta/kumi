# frozen_string_literal: true

require_relative "../../lib/kumi/core/compiler/access_planner"
require_relative "../../lib/kumi/core/compiler/access_builder"

RSpec.describe "AccessPlanner + AccessBuilder edge cases" do
  def build_accessors(meta, **opts)
    plans = Kumi::Core::Compiler::AccessPlanner.plan(meta, opts)
    Kumi::Core::Compiler::AccessBuilder.build(plans)
  end

  context "depth=0 (:object)" do
    it "fetches scalar leaves with on_missing policies" do
      meta = { name: { type: :string } }
      acc  = build_accessors(meta, on_missing: :nil)
      data = { "name" => "Ada" }
      expect(acc["name:object"].call(data)).to eq("Ada")
      expect(acc["name:object"].call({})).to eq(nil)
    end

    it "returns hash leaves intact" do
      meta = { user: { type: :object, children: { first: { type: :string } } } }
      acc  = build_accessors(meta)
      data = { "user" => { "first" => "Linus" } }
      expect(acc["user:object"].call(data)).to eq({ "first" => "Linus" })
    end

    it "does not emit :each_indexed/:materialize/:ravel for depth=0" do
      meta = { name: { type: :string } }
      plans = Kumi::Core::Compiler::AccessPlanner.plan(meta)

      expect(plans["name"].map(&:mode)).to contain_exactly(:object)
    end
  end

  context "key_policy" do
    it "honors :string / :symbol / :indifferent in all modes" do
      meta = { regions: { type: :array, children: { tax_rate: { type: :float } } } }
      data = { "regions" => [{ "tax_rate" => 0.2 }, { tax_rate: 0.15 }] }

      acc_ind = build_accessors(meta, on_missing: :skip, key_policy: :indifferent)
      acc_str = build_accessors(meta, on_missing: :skip, key_policy: :string)
      acc_sym = build_accessors(meta, on_missing: :skip, key_policy: :symbol)

      expect(acc_ind["regions.tax_rate:materialize"].call(data)).to eq([0.2, 0.15])
      expect(acc_str["regions.tax_rate:materialize"].call(data)).to eq([0.2, nil])   # second is symbol-keyed
      expect(acc_sym["regions.tax_rate:materialize"].call(data)).to eq([nil, 0.15])  # first is string-keyed
    end
  end

  context "on_missing policy" do
    let(:meta) do
      { regions: { type: :array, children: { offices: { type: :array, children: { revenue: { type: :float } } } } } }
    end

    it ":ravel with :nil yields nils; with :skip drops elements" do
      data = { "regions" => [{ "offices" => [{}, { "revenue" => 2.0 }] }, { "offices" => [] }] }
      acc_nil  = build_accessors(meta, on_missing: :nil)
      acc_skip = build_accessors(meta, on_missing: :skip)

      expect(acc_nil["regions.offices.revenue:ravel"].call(data)).to eq([nil, 2.0]) # two leaf positions
      expect(acc_skip["regions.offices.revenue:ravel"].call(data)).to eq([2.0]) # missing leaf skipped
    end

    it ":materialize keeps outer shape; :skip returns [] for missing arrays" do
      data = { "regions" => [{ "offices" => nil }, { "offices" => [{ "revenue" => 1.0 }] }] }
      acc_nil  = build_accessors(meta, on_missing: :nil)
      acc_skip = build_accessors(meta, on_missing: :skip)

      expect(acc_nil["regions.offices.revenue:materialize"].call(data)).to eq([nil, [1.0]])
      expect(acc_skip["regions.offices.revenue:materialize"].call(data)).to eq([[], [1.0]])
    end

    it "raises on :error for missing keys/arrays with clear messages" do
      data = { "regions" => [{}, { "offices" => [{ "revenue" => 1.0 }] }] }
      acc = build_accessors(meta, on_missing: :error)
      expect do
        acc["regions.offices.revenue:ravel"].call(data)
      end.to raise_error(KeyError, /Missing key 'offices'.*regions\.offices\.revenue/i)
    end
  end

  context "type violations" do
    it "TypeError when expecting Hash" do
      meta = { regions: { type: :array, children: { tax_rate: { type: :float } } } }
      acc  = build_accessors(meta)
      data = { "regions" => ["not a hash"] }
      expect do
        acc["regions.tax_rate:materialize"].call(data)
      end.to raise_error(TypeError, /Expected Hash/)
    end

    it "TypeError when expecting Array" do
      meta = { regions: { type: :array, children: { tax_rate: { type: :float } } } }
      acc  = build_accessors(meta)
      data = { "regions" => { "tax_rate" => 0.2 } }
      expect do
        acc["regions.tax_rate:ravel"].call(data)
      end.to raise_error(TypeError, /Expected Array/)
    end
  end

  context "enumeration semantics" do
    it ":each_indexed order matches DFS left-to-right and aligns with :materialize" do
      meta = { regions: { type: :array, children: { offices: { type: :array, children: { rev: { type: :float } } } } } }
      data = { "regions" => [{ "offices" => [{ "rev" => 1.0 }, { "rev" => 2.0 }] }, { "offices" => [{ "rev" => 3.0 }] }] }
      acc  = build_accessors(meta)

      mat = acc["regions.offices.rev:materialize"].call(data)
      enum = acc["regions.offices.rev:each_indexed"].call(data).to_a

      expect(enum.map(&:first)).to eq([1.0, 2.0, 3.0])
      expect(enum.map(&:last)).to eq([[0, 0], [0, 1], [1, 0]])
      expect(mat.flatten).to eq(enum.map(&:first))
    end

    it ":each_indexed yields two args to block" do
      meta = { regions: { type: :array, children: { tax_rate: { type: :float } } } }
      data = { "regions" => [{ "tax_rate" => 0.2 }, { "tax_rate" => 0.15 }] }
      acc  = build_accessors(meta)

      seen = []
      acc["regions.tax_rate:each_indexed"].call(data) { |v, idx| seen << [v, idx] }
      expect(seen).to eq([[0.2, [0]], [0.15, [1]]])
    end
  end

  context "leaf as object" do
    it "returns hashes at the endpoint" do
      meta = { regions: { type: :array, children: { info: { type: :object, children: { code: { type: :string } } } } } }
      data = { "regions" => [{ "info" => { "code" => "NE" } }, { "info" => { "code" => "SW" } }] }
      acc  = build_accessors(meta)

      expect(acc["regions.info:materialize"].call(data)).to eq([{ "code" => "NE" }, { "code" => "SW" }])
      expect(acc["regions.info:ravel"].call(data)).to eq([{ "code" => "NE" }, { "code" => "SW" }])
      enum = acc["regions.info:each_indexed"].call(data).to_a
      expect(enum).to eq([[{ "code" => "NE" }, [0]], [{ "code" => "SW" }, [1]]])
    end
  end
end
