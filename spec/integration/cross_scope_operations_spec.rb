# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cross-Scope Operations" do
  describe "Current State: Operations blocked at analyzer level" do
    it "blocks simple cross-scope operations" do
      expect do
        Module.new do
          extend Kumi::Schema

          schema do
            input do
              array :left_data do
                string :name
              end
              array :right_data do
                integer :value
              end
            end

            # This fails at analyzer level, never reaches VM
            value :cross_scope_concat, fn(:concat, input.left_data.name, input.right_data.value)
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /cross-scope map without join/)
    end

    it "blocks cross-scope arithmetic operations" do
      expect do
        Module.new do
          extend Kumi::Schema

          schema do
            input do
              array :prices do
                float :amount
              end
              array :quantities do
                integer :count
              end
            end

            # This fails at analyzer level, never reaches VM
            value :totals, input.prices.amount * input.quantities.count
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /cross-scope map without join/)
    end

    it "blocks cross-scope array operations" do
      # Array literals might be handled differently, let's test a function call instead
      expect do
        Module.new do
          extend Kumi::Schema

          schema do
            input do
              array :left_items do
                string :category
              end
              array :right_items do
                float :score
              end
            end

            # This fails at analyzer level, never reaches VM
            value :comparison, fn(:greater_than, input.left_items.category, input.right_items.score)
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /cross-scope map without join/)
    end
  end


  describe "What PR B Should Enable" do
    # These are the tests that should pass AFTER PR B is implemented
    # Currently they all fail, but they document the target behavior

    context "after LowerToIR emits :join operations" do
      # NOTE: These tests will fail until PR B is implemented
      # They serve as acceptance criteria for PR B

      it "supports simple cross-scope concatenation" do
        schema = Module.new do
          extend Kumi::Schema

          schema do
            input do
              array :names do
                string :first
              end
              array :ages do
                integer :value
              end
            end

            # After PR B: This should emit :join + :map instead of failing
            value :name_age_pairs, fn(:concat, input.names.first, " (", input.ages.value, ")")
          end
        end

        result = schema.from({
                               names: [{ first: "Alice" }, { first: "Bob" }],
                               ages: [{ value: 25 }, { value: 30 }]
                             })

        expect(result[:name_age_pairs][:rows].map { |r| r[:v] }).to eq(["Alice (25)", "Bob (30)"])
      end

      xit "should support cross-scope arithmetic operations" do
        schema = Module.new do
          extend Kumi::Schema

          schema do
            input do
              array :base_prices do
                float :amount
              end
              array :multipliers do
                float :factor
              end
            end

            # After PR B: This should emit :join + :map instead of failing
            value :final_prices, input.base_prices.amount * input.multipliers.factor
          end
        end

        result = schema.from({
                               base_prices: [{ amount: 10.0 }, { amount: 20.0 }],
                               multipliers: [{ factor: 1.1 }, { factor: 1.2 }]
                             })

        expect(result[:final_prices]).to eq([11.0, 24.0])
      end

      xit "should support cross-scope array construction" do
        schema = Module.new do
          extend Kumi::Schema

          schema do
            input do
              array :products do
                string :name
              end
              array :inventory do
                integer :stock
              end
            end

            # After PR B: This should emit :join + :map instead of failing
            value :product_inventory, [input.products.name, input.inventory.stock]
          end
        end

        result = schema.from({
                               products: [{ name: "Widget" }, { name: "Gadget" }],
                               inventory: [{ stock: 5 }, { stock: 10 }]
                             })

        expect(result[:product_inventory]).to eq([["Widget", 5], ["Gadget", 10]])
      end
    end
  end

  describe "Edge Cases for PR B" do
    context "length mismatch handling" do
      xit "should handle length mismatches according to function signatures" do
        # After PR B + function signature metadata:
        # Different functions might specify different join policies
        # This would require function registry enhancements
        pending "Requires function signature metadata for join policies"
      end
    end

    context "nested cross-scope operations" do
      xit "should handle cross-scope operations with nested arrays" do
        # After PR B: Complex nested structures with cross-scope references
        pending "Requires PR B + nested scope resolution"
      end
    end
  end
end
