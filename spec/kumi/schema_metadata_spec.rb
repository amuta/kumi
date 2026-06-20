# frozen_string_literal: true

RSpec.describe Kumi::SchemaMetadata do
  def build(&block)
    Class.new { extend Kumi::Schema }.tap { |c| c.schema(&block) }.schema_metadata
  end

  describe "input fields" do
    let(:md) do
      build do
        input do
          integer :age, domain: 18..99
          array :items do
            hash :item do
              integer :qty, domain: 1..100
              float :price
            end
          end
        end
        value :line, input.items.item.qty * input.items.item.price
      end
    end

    it "lifts each leaf with type, domain, axes and element_path" do
      age = md.input_field(:age)
      expect(age.type).to eq(:integer)
      expect(age.domain).to eq(18..99)
      expect(age.axes).to eq([])

      qty = md.input_field(%i[items item qty])
      expect(qty.type).to eq(:integer)
      expect(qty.axes).to eq([:items])
      expect(qty.element_path).to eq([:qty])
      expect(qty.in_array).to be(true)
    end

    it "resolves a field by dotted string" do
      expect(md.input_field("items.item.price").type).to eq(:float)
    end
  end

  describe "definitions as algebra" do
    let(:md) do
      build do
        input do
          integer :age, domain: 18..99
          float :income
        end
        trait :adult, input.age >= 18
        value :line, input.income * 2
        value :tier do
          on adult, "yes"
          base "no"
        end
      end
    end

    it "classifies values and traits" do
      expect(md.value_names).to contain_exactly(:line, :tier)
      expect(md.trait_names).to contain_exactly(:adult)
    end

    it "renders each definition's expression" do
      expect(md.definition(:adult).expression).to eq("(input.age >= 18)")
      expect(md.definition(:line).expression).to eq("(input.income * 2)")
      expect(md.definition(:tier).expression).to include("cascade")
    end

    it "exposes the dependency relation both ways" do
      expect(md.reads(:tier)).to include(:adult)
      expect(md.read_by(:age)).to include(:adult)
    end

    it "gives a topological evaluation order" do
      order = md.evaluation_order
      expect(order.index(:adult)).to be < order.index(:tier)
    end
  end

  describe "axis tracking through reductions" do
    let(:md) do
      build do
        input do
          array :rows do
            hash :row do
              array :cols do
                hash :col do
                  float :v
                end
              end
            end
          end
        end
        value :cells, input.rows.row.cols.col.v
        value :row_sums, fn(:sum, cells)
      end
    end

    it "tracks the axes a value spans" do
      expect(md.definition(:cells).axes).to eq(%i[rows cols])
    end

    it "shows a reduction collapsing the innermost axis" do
      expect(md.definition(:row_sums).axes).to eq([:rows])
    end
  end

  # The regression the renderer's positional heuristic got wrong: a path with no
  # hash element-selector keys must not have real array levels dropped.
  describe "non-alternating (selector-less) nested paths" do
    it "renders array-of-array paths faithfully" do
      md = build do
        input { array(:x) { array(:y) { integer :v } } }
        value :s, fn(:sum, input.x.y.v)
      end
      expect(md.definition(:s).expression).to eq("sum(input.x.y.v)")
      expect(md.input_field(%i[x y v]).axes).to eq(%i[x y])
    end

    it "renders a deep array-of-array-of-array path faithfully" do
      md = build do
        input { array(:cube) { array(:layer) { array(:row) { integer :cell } } } }
        trait :over, input.cube.layer.row.cell > 100
      end
      expect(md.definition(:over).expression).to eq("(input.cube.layer.row.cell > 100)")
    end

    it "renders hash-only nested paths faithfully" do
      md = build do
        input { hash(:a) { hash(:b) { integer :z } } }
        value :double, input.a.b.z * 2
      end
      expect(md.definition(:double).expression).to eq("(input.a.b.z * 2)")
    end

    it "renders mixed array/hash nesting with selector keys faithfully" do
      md = build do
        input do
          array :batch do
            hash :b do
              array :row do
                hash :r do
                  float :scale
                end
              end
            end
          end
        end
        value :scaled, input.batch.b.row.r.scale * 2.0
      end
      expect(md.definition(:scaled).expression).to eq("(input.batch.b.row.r.scale * 2.0)")
    end
  end

  # The printer's input-name shortening must also keep every array level. Built
  # from authoritative axis data, so it is lossless regardless of selector keys.
  describe "printer input names keep every axis" do
    it "keeps all levels for selector-less array-of-array" do
      md = build do
        input { array(:x) { array(:y) { integer :v } } }
        value :s, fn(:sum, input.x.y.v)
      end
      expect(md.to_s).to include("x.y.v")
      expect(md.to_s).to include("@[x x y]")
    end

    it "keeps all levels for deeply nested arrays with selector keys" do
      md = build do
        input do
          array :regions do
            hash :region do
              array :offices do
                hash :office do
                  float :budget
                end
              end
            end
          end
        end
        value :total, fn(:sum, input.regions.region.offices.office.budget)
      end
      expect(md.to_s).to include("regions.offices.budget")
    end
  end

  describe "serialization" do
    let(:md) do
      build do
        input do
          integer :age, domain: 18..99
          array :items do
            hash :item do
              float :price
            end
          end
        end
        value :line, input.items.item.price * 2
        value :total, fn(:sum, line)
      end
    end

    it "produces a JSON-round-trippable hash" do
      require "json"
      round = JSON.parse(JSON.generate(md.to_h))
      expect(round["inputs"]).to be_an(Array)
      expect(round["definitions"]).to be_an(Array)
      expect(round["evaluation_order"]).to include("line", "total")
    end

    it "renders a human-readable report" do
      report = md.to_s
      expect(report).to include("INPUTS")
      expect(report).to include("DEFINITIONS")
      expect(report).to include("EVALUATION ORDER")
    end
  end
end
