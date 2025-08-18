# frozen_string_literal: true

require "spec_helper"
require_relative "../support/analyzer_state_helper"

RSpec.describe "Analyzer integration: Signature + Cascade scalarization" do
  include AnalyzerStateHelper

  context "signature resolution uses decl scopes (no :broadcast_metadata needed)" do
    it "resolves a vector + scalar concat by consuming :decl_shapes from ScopeResolution" do
      state = analyze_up_to(:scope_plans) do
        input do
          array :users do
            string :name
          end
        end

        # Vector producer
        value :names, input.users.name
        # Should resolve as concat(vector, scalar) via zip policy
        value :greet, fn(:concat, names, "!")
      end

      expect(state[:decl_shapes]).not_to be_nil
      expect(state[:decl_shapes].dig(:names, :scope)).not_to eq([]) # names is vector
      expect(state[:decl_shapes].dig(:greet, :scope)).not_to be_nil # greet has a scope defined

      # Also verify no analyzer errors
      schema_mod = Module.new.extend(Kumi::Schema)
      expect {
        schema_mod.schema do
          input do
            array :users do
              string :name
            end
          end
          value :names, input.users.name
          value :greet, fn(:concat, names, "!")
        end
      }.not_to raise_error
    end
  end

  context "cascade conflicts are scalarized to avoid vector guards" do
    it "forces scalar scope when mixing roots inside a cascade" do
      state = analyze_up_to(:scope_plans) do
        input do
          array :users do
            integer :age
          end
          array :orders do
            float :amount
          end
        end

        # Define traits first, then use them in cascade
        trait :is_adult, input.users.age, :>, 18
        trait :has_orders, input.orders.amount, :>, 0

        # Conflict: condition over users, branch over orders (mixed roots)
        value :flagged do
          on is_adult, input.orders.amount
          base 0.0
        end
      end

      expect(state[:scope_plans]).not_to be_nil
      # The scope for flagged should be forced to scalar due to mixed roots
      expect(state[:scope_plans].dig(:flagged, :scope)).to eq([])

      # Also verify that full schema compilation works
      schema_mod = Module.new.extend(Kumi::Schema)
      expect {
        schema_mod.schema do
          input do
            array :users do
              integer :age
            end
            array :orders do
              float :amount
            end
          end
          trait :is_adult, input.users.age, :>, 18
          trait :has_orders, input.orders.amount, :>, 0
          value :flagged do
            on is_adult, input.orders.amount
            base 0.0
          end
        end
      }.not_to raise_error
    end
  end
end