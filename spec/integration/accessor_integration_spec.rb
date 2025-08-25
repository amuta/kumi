# frozen_string_literal: true

require_relative "../support/analyzer_state_helper"
require_relative "../support/strategy_test_helper"

RSpec.describe "AccessPlanner + AccessBuilder Integration" do
  include AnalyzerStateHelper

  test_both_strategies do
    it "works with simple array of objects" do
      # Define schema properly and get metadata from InputCollector
      # This creates an array of objects with tax_rate field
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :regions do
            float :tax_rate
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      test_data = {
        "regions" => [
          { "tax_rate" => 0.2 },
          { "tax_rate" => 0.15 }
        ]
      }

      # Verify expected accessor keys exist
      expect(accessors).to have_key("regions:ravel")
      expect(accessors).to have_key("regions.tax_rate:ravel")
      expect(accessors).to have_key("regions.tax_rate:materialize")
      expect(accessors).to have_key("regions.tax_rate:each_indexed")

      # Test regions:ravel - ravel yields the terminal node; for container paths that's [array]
      result = accessors["regions:ravel"].call(test_data)
      expect(result).to eq([{ "tax_rate" => 0.2 }, { "tax_rate" => 0.15 }])

      # Test regions.tax_rate:ravel - should extract just the values
      result = accessors["regions.tax_rate:ravel"].call(test_data)
      expect(result).to eq([0.2, 0.15])

      # Test regions.tax_rate:materialize - should preserve structure
      result = accessors["regions.tax_rate:materialize"].call(test_data)
      expect(result).to eq([0.2, 0.15])

      # Test regions.tax_rate:each_indexed
      seen = []
      accessors["regions.tax_rate:each_indexed"].call(test_data) { |v, idx| seen << [v, idx] }
      expect(seen).to eq([[0.2, [0]], [0.15, [1]]])
    end

    it "works with nested hashes" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          hash :user do
            hash :contact do
              string :doc_id
            end
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      # Only read key should exist
      expect(accessors).to have_key("user.contact.doc_id:read")
      expect(accessors).not_to have_key("user.contact.doc_id:materialize")
      expect(accessors).not_to have_key("user.contact.doc_id:ravel")
      expect(accessors).not_to have_key("user.contact.doc_id:each_indexed")

      test_data = {
        user: { contact: { doc_id: "998-999" } }
      }

      # Test regions.offices.revenue:materialize - should preserve 2D structure
      result = accessors["user.contact.doc_id:read"].call(test_data)
      expect(result).to eq("998-999")
    end

    it "works with nested arrays" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :regions do
            array :offices do
              float :revenue
            end
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      # Verify expected accessor keys exist
      expect(accessors).to have_key("regions.offices.revenue:materialize")
      expect(accessors).to have_key("regions.offices.revenue:ravel")
      expect(accessors).to have_key("regions.offices.revenue:each_indexed")

      test_data = {
        "regions" => [
          { "offices" => [{ "revenue" => 100.0 }, { "revenue" => 200.0 }] },
          { "offices" => [{ "revenue" => 150.0 }] }
        ]
      }

      # Test regions.offices.revenue:materialize - should preserve 2D structure
      result = accessors["regions.offices.revenue:materialize"].call(test_data)
      expect(result).to eq([[100.0, 200.0], [150.0]])

      # Test regions.offices.revenue:ravel - should flatten completely
      result = accessors["regions.offices.revenue:ravel"].call(test_data)
      expect(result).to eq([100.0, 200.0, 150.0])

      # Test regions.offices.revenue:each_indexed - should have 2D indices
      seen = []
      accessors["regions.offices.revenue:each_indexed"].call(test_data) { |v, idx| seen << [v, idx] }
      expect(seen).to eq([
                           [100.0, [0, 0]],
                           [200.0, [0, 1]],
                           [150.0, [1, 0]]
                         ])
    end

    it "handles mixed symbol/string keys" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :regions do
            float :tax_rate
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      # Mixed symbols and strings in data
      test_data = {
        regions: [
          { "tax_rate" => 0.2 },
          { tax_rate: 0.15 }
        ]
      }

      result = accessors["regions.tax_rate:materialize"].call(test_data)
      expect(result).to eq([0.2, 0.15])
    end

    it "returns nils on missing keys when configured" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :regions do
            float :tax_rate
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata, on_missing: :nil)
      accessors = build_accessors_with_strategy(plans)

      test_data = {
        "regions" => [
          {}, # Missing tax_rate
          { "tax_rate" => 0.15 }
        ]
      }

      result = accessors["regions.tax_rate:ravel"].call(test_data)
      expect(result).to eq([nil, 0.15])
    end

    it "handles empty arrays at any level" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :regions do
            array :offices do
              float :revenue
            end
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      # Empty at top level
      expect(accessors["regions.offices.revenue:materialize"].call({ "regions" => [] })).to eq([])

      # Empty at nested level
      expect(accessors["regions.offices.revenue:materialize"].call({ "regions" => [{ "offices" => [] }] })).to eq([[]])
    end

    it "works with element access mode arrays" do
      # Test the inline array case (what the original test was trying to create)
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :matrix do
            element :array, :row do
              element :float, :value
            end
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      # Test data: nested arrays (matrix)
      test_data = {
        "matrix" => [
          [1.0, 2.0, 3.0],
          [4.0, 5.0, 6.0]
        ]
      }

      # For element access, the values ARE the arrays/scalars themselves
      result = accessors["matrix.row.value:ravel"].call(test_data)
      expect(result).to eq([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    end

    it "works with pure element arrays (3D matrix)" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :cube do
            element :array, :layer do
              element :array, :row do
                element :float, :cell
              end
            end
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      test_data = {
        "cube" => [
          [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
          [[7.0, 8.0, 9.0], [10.0, 11.0, 12.0]]
        ]
      }

      # For nested scalar arrays, the materialized accessors should return the original structure
      expect(accessors["cube:materialize"].call(test_data)).to eq(test_data["cube"])
      expect(accessors["cube.layer:materialize"].call(test_data)).to eq(test_data["cube"])
      expect(accessors["cube.layer.row:materialize"].call(test_data)).to eq(test_data["cube"])
      expect(accessors["cube.layer.row.cell:materialize"].call(test_data)).to eq(test_data["cube"])

      # for ravel, it will return the flattened version of the 3D structure over N dimensions (path length)
      expect(accessors["cube:ravel"].call(test_data)).to eq(test_data["cube"])
      expect(accessors["cube.layer:ravel"].call(test_data)).to eq(test_data["cube"].flatten(1))
      expect(accessors["cube.layer.row:ravel"].call(test_data)).to eq(test_data["cube"].flatten(2))

      # Because the cells are leafs and its vectorized version is an array over the cells, which is the same
      # as the row:ravel
      expect(accessors["cube.layer.row.cell:ravel"].call(test_data)).to eq(test_data["cube"].flatten(2))

      # For each_indexed, it should yield each value with its 3D index
      # 1 axis → layers
      seen = []
      accessors["cube:each_indexed"].call(test_data) { |v, idx| seen << [v, idx] }
      expect(seen).to eq([
                           [[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]], [0]],
                           [[[7.0, 8.0, 9.0], [10.0, 11.0, 12.0]], [1]]
                         ])

      # 2 axes → rows across layers
      seen = []
      accessors["cube.layer:each_indexed"].call(test_data) { |v, idx| seen << [v, idx] }
      expect(seen).to eq([
                           [[1.0, 2.0, 3.0], [0, 0]],
                           [[4.0, 5.0, 6.0], [0, 1]],
                           [[7.0, 8.0, 9.0], [1, 0]],
                           [[10.0, 11.0, 12.0], [1, 1]]
                         ])

      # 3 axes → scalar cells
      seen = []
      accessors["cube.layer.row:each_indexed"].call(test_data) { |v, idx| seen << [v, idx] }
      expect(seen.first(4)).to eq([
                                    [1.0, [0, 0, 0]],
                                    [2.0, [0, 0, 1]],
                                    [3.0, [0, 0, 2]],
                                    [4.0, [0, 1, 0]]
                                  ])
      expect(seen.last(2)).to eq([
                                   [11.0, [1, 1, 1]],
                                   [12.0, [1, 1, 2]]
                                 ])
      expect(seen.size).to eq(12)

      # explicit leaf name yields the same sequence/indices as its parent
      seen2 = []
      accessors["cube.layer.row.cell:each_indexed"].call(test_data) do |v, idx|
        seen2 << [v, idx]
      end
      expect(seen2).to eq(seen)
    end

    it "works with objects containing pure element arrays" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :players do
            string :name
            integer :score
          end
        end
      end

      element_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :coordinates do
            element :array, :point do
              element :float, :axis
            end
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      element_plans = Kumi::Core::Compiler::AccessPlanner.plan(element_metadata)
      element_accessors = build_accessors_with_strategy(element_plans)

      test_data = {
        "players" => [
          { "name" => "Alice", "score" => 100 },
          { "name" => "Bob", "score" => 85 }
        ]
      }

      element_data = {
        "coordinates" => [
          [10.0, 20.0],
          [15.0, 25.0],
          [5.0, 15.0]
        ]
      }

      result = accessors["players.name:ravel"].call(test_data)
      expect(result).to eq(%w[Alice Bob])

      result = accessors["players.score:ravel"].call(test_data)
      expect(result).to eq([100, 85])

      result = element_accessors["coordinates.point.axis:ravel"].call(element_data)
      expect(result).to eq([10.0, 20.0, 15.0, 25.0, 5.0, 15.0])

      seen = []
      element_accessors["coordinates.point.axis:each_indexed"].call(element_data) { |v, idx| seen << [v, idx] }
      expect(seen).to eq([
                           [10.0, [0, 0]],
                           [20.0, [0, 1]],
                           [15.0, [1, 0]],
                           [25.0, [1, 1]],
                           [5.0,  [2, 0]],
                           [15.0, [2, 1]]
                         ])
    end

    it "handles field-hop arrays inside element objects" do
      input_metadata = get_analyzer_state(:input_metadata) do
        input do
          array :rows do
            integer :id
            array :tags do
              string :tag
            end
          end
        end
      end

      plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
      accessors = build_accessors_with_strategy(plans)

      # Verify expected accessor keys exist
      expect(accessors).to have_key("rows.tags.tag:materialize")

      test_data = {
        "rows" => [
          { "id" => 1, "tags" => [{ "tag" => "a" }, { "tag" => "b" }] }
        ]
      }

      result = accessors["rows.tags.tag:materialize"].call(test_data)
      expect(result).to eq([%w[a b]])
    end
  end
end
