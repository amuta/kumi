# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::CascadeDesugarPass do
  include AnalyzerStateHelper

  describe "cascade_and semantics" do
    context "single argument → identity" do
      it "marks single-argument cascade_and for identity desugaring" do
        # Get the node index after CascadeDesugarPass runs (pass index 8)
        state = analyze_up_to(:evaluation_order) do
          input do
            integer :x
          end
          trait :t1, input.x > 10
          value :simple_cascade do
            on t1, "big"
            base "small"
          end
        end

        node_index = state[:node_index]

        # Find cascade_and nodes
        cascade_and_nodes = node_index.values.select do |entry|
          entry[:type] == "CallExpression" && entry[:node].fn_name == :cascade_and
        end

        expect(cascade_and_nodes).to have(1).item
        node_entry = cascade_and_nodes.first
        metadata = node_entry[:metadata] || {}

        expect(metadata[:desugar_to_identity]).to be(true)
        expect(metadata[:identity_arg]).to be_a(Kumi::Syntax::DeclarationReference)
        expect(metadata[:identity_arg].name).to eq(:t1)
      end
    end

    context "multiple arguments → boolean AND" do
      it "marks multi-argument cascade_and for core.and desugaring" do
        state = analyze_up_to(:evaluation_order) do
          input do
            integer :x
            integer :y
          end
          trait :t1, input.x > 10
          trait :t2, input.y < 50
          value :complex_cascade do
            on fn(:cascade_and, t1, t2), "both"
            base "neither"
          end
        end

        node_index = state[:node_index]
        cascade_and_nodes = node_index.values.select do |entry|
          entry[:type] == "CallExpression" && entry[:node].fn_name == :cascade_and
        end

        # Find the multi-argument cascade_and
        multi_arg_node = cascade_and_nodes.find { |entry| entry[:node].args.size == 2 }
        expect(multi_arg_node).not_to be_nil

        metadata = multi_arg_node[:metadata] || {}
        expect(metadata[:desugared_to]).to eq(:and)
        expect(metadata[:qualified_name]).to eq("core.and")
      end
    end

    context "empty arguments → semantic error" do
      it "reports semantic error for empty cascade_and" do
        expect do
          analyze_up_to(:evaluation_order) do
            input do
              integer :x
            end
            value :invalid_cascade do
              on fn(:cascade_and), "invalid"
              base "default"
            end
          end
        end.to raise_error(/cascade_and requires at least one condition/)
      end
    end
  end

  describe "function signature integration" do
    it "skips signature resolution for cascade_and nodes marked for desugaring" do
      # This should not raise "unknown function core.cascade_and" error
      expect do
        analyze_up_to(:evaluation_order) do
          input do
            integer :x
          end
          trait :t1, input.x > 10
          value :simple_cascade do
            on t1, "big"
            base "small"
          end
        end
      end.not_to raise_error
    end

    it "does not require core.cascade_and in function registry" do
      # Verify that core.cascade_and is not defined in the registry
      registry = Kumi::Core::Functions::RegistryV2.load_from_file
      expect(registry.function_exists?("core.cascade_and")).to be(false)
    end
  end

  describe "integration with IR generation" do
    it "generates identity reference for single-argument cascade_and" do
      # Test that single-arg cascade_and becomes just a ref in the IR
      state = analyze_up_to(:ir_module) do
        input do
          integer :x
        end
        trait :t1, input.x > 10
        value :simple_cascade do
          on t1, "big"
          base "small"
        end
      end

      ir_module = state[:ir_module]
      cascade_decl = ir_module.declarations.find { |d| d.name == :simple_cascade }
      expect(cascade_decl).not_to be_nil

      # Convert to debug dump format to check operations
      debug_dump = ir_module.debug_dump
      cascade_section = debug_dump.split("Declaration: simple_cascade")[1]

      # Should contain ref operations for trait access, not cascade_and calls
      expect(cascade_section).to include('ref {:name=>:t1}')
      expect(cascade_section).not_to include('cascade_and')
    end
  end
end