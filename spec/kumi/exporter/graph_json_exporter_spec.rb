# frozen_string_literal: true

RSpec.describe Kumi::Exporter::GraphJsonExporter do
  describe ".export" do
    let(:schema) do
      Kumi::Parser::Dsl.build_sytax_tree do
        predicate :is_active, key(:status), :==, "active"
        predicate :high_value, key(:value), :>, 100

        value :important_item, fn(:all?, [ref(:is_active), ref(:high_value)])
      end
    end

    it "generates a JSON with labeled edges and input nodes" do
      json_output = described_class.export(schema)
      graph = JSON.parse(json_output, symbolize_names: true)

      # --- Verify Nodes ---
      # It should identify all declared definitions plus the raw key inputs.
      node_ids = graph[:nodes].map { |n| n[:id] }
      expect(node_ids).to contain_exactly(
        "is_active",
        "high_value",
        "important_item",
        "status", # Auto-detected input node
        "value"   # Auto-detected input node
      )

      # --- Verify Edges ---
      # It should create edges with labels derived from the operation.
      edges = graph[:edges].map { |e| [e[:source], e[:target], e[:label]] }
      expect(edges).to contain_exactly(
        # predicate :is_active, key(:status), :==, "active"
        ["is_active", "status", "=="],
        # predicate :high_value, key(:value), :>, 100
        ["high_value", "value", ">"],
        # value :important_item, fn(:all?, [ref(:is_active), ref(:high_value)])
        ["important_item", "is_active", "all?"],
        ["important_item", "high_value", "all?"]
      )
    end
  end
end
