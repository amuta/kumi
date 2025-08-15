# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Join Operations Integration" do
  describe "VM-level join functionality" do
    # This spec tests the join operations at the VM/IR level
    # End-to-end DSL support requires PR B (LowerToIR emitting :join operations)
    
    context "direct IR execution with join operations" do
      def ir_module(decls)
        Kumi::Core::IR::Module.new(inputs: {}, decls: decls)
      end

      def ir_decl(name, ops)
        Kumi::Core::IR::Decl.new(name: name, kind: :value, shape: nil, ops: ops)
      end

      def ir_op(tag, attrs = {}, args = [])
        Kumi::Core::IR::Op.new(tag: tag, attrs: attrs, args: args)
      end

      def registry
        Kumi::Registry.functions
      end

      it "executes cross-scope joins at the VM level" do
        accessors = {
          "left:each" => ->(ctx) { ["A", "B"] },
          "right:each" => ->(ctx) { [1, 2] }
        }

        # This IR demonstrates what LowerToIR should generate for cross-scope operations
        ir = ir_module([
                         ir_decl(:cross_scope_result, [
                                   # Load left array
                                   ir_op(:load_input, { plan_id: "left:each", scope: [:left], is_scalar: false, has_idx: false }),
                                   # Load right array  
                                   ir_op(:load_input, { plan_id: "right:each", scope: [:right], is_scalar: false, has_idx: false }),
                                   # Join them with zip policy
                                   ir_op(:join, { policy: :zip, on_missing: :error }, [0, 1]),
                                   # Apply function to joined pairs
                                   ir_op(:map, { fn: :concat, argc: 2 }, [2]),
                                   ir_op(:store, { name: :cross_scope_result }, [3])
                                 ])
                       ])

        result = Kumi::Core::IR::ExecutionEngine::Interpreter.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:cross_scope_result][:k]).to eq(:vec)
        expect(result[:cross_scope_result][:scope]).to eq([:left, :right])
        expect(result[:cross_scope_result][:rows]).to eq([
                                                           { v: "A1" },
                                                           { v: "B2" }
                                                         ])
      end

      it "handles mathematical operations on joined vectors" do
        accessors = {
          "prices:each" => ->(ctx) { [10.5, 20.0] },
          "quantities:each" => ->(ctx) { [2, 3] }
        }

        ir = ir_module([
                         ir_decl(:totals, [
                                   ir_op(:load_input, { plan_id: "prices:each", scope: [:prices], is_scalar: false, has_idx: false }),
                                   ir_op(:load_input, { plan_id: "quantities:each", scope: [:quantities], is_scalar: false, has_idx: false }),
                                   ir_op(:join, { policy: :zip, on_missing: :error }, [0, 1]),
                                   ir_op(:map, { fn: :multiply, argc: 2 }, [2]),
                                   ir_op(:store, { name: :totals }, [3])
                                 ])
                       ])

        result = Kumi::Core::IR::ExecutionEngine::Interpreter.run(ir, { input: {} }, accessors: accessors, registry: registry)

        expect(result[:totals][:rows].map { |r| r[:v] }).to eq([21.0, 60.0])
      end
    end
  end

  describe "Current DSL limitations (requires PR B)" do
    # These tests document what currently fails and should work after PR B
    
    context "with cross-scope operations in DSL" do
      it "currently fails with cross-scope map without join error" do
        expect do
          Module.new do
            extend Kumi::Schema
            
            schema do
              input do
                array :left_items do
                  string :name
                end
                array :right_items do  
                  string :category
                end
              end
              
              # This currently fails but should work after PR B
              value :combined, fn(:concat, input.left_items.name, input.right_items.category)
            end
          end
        end.to raise_error(Kumi::Core::Errors::SemanticError, /cross-scope map without join/)
      end

      it "currently fails with arithmetic operations across scopes" do
        expect do
          Module.new do
            extend Kumi::Schema
            
            schema do
              input do
                array :values1 do
                  integer :x
                end
                array :values2 do
                  integer :y
                end
              end
              
              # This currently fails but should work after PR B
              value :sums, input.values1.x + input.values2.y
            end
          end
        end.to raise_error(Kumi::Core::Errors::SemanticError, /cross-scope map without join/)
      end
    end
  end

  describe "Same-scope operations (currently supported)" do
    context "with operations within the same array scope" do
      module SameScopeSchema
        extend Kumi::Schema
        
        schema do
          input do
            array :items do
              string :name
              integer :value
              float :price
            end
          end
          
          # These work because they're all from the same scope
          value :combined_info, fn(:concat, input.items.name, ": $", input.items.price)
          value :total_cost, input.items.value * input.items.price
          value :item_summary, [input.items.name, input.items.value, input.items.price]
        end
      end

      let(:same_scope_data) do
        {
          items: [
            { name: "Item1", value: 2, price: 10.5 },
            { name: "Item2", value: 3, price: 15.0 }
          ]
        }
      end

      it "performs operations within the same array scope" do
        result = SameScopeSchema.from(same_scope_data)
        
        expect(result[:combined_info]).to eq(["Item1: $10.5", "Item2: $15.0"])
        expect(result[:total_cost]).to eq([21.0, 45.0])
        expect(result[:item_summary]).to eq([
          ["Item1", 2, 10.5],
          ["Item2", 3, 15.0]
        ])
      end
    end
  end
end