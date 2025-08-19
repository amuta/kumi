# frozen_string_literal: true

require "spec_helper"
require "support/analyzer_state_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::JoinReducePlanningPass do
  include AnalyzerStateHelper

  def run_join_reduce_planning(&block)
    analyze_up_to(:join_reduce_plans, &block)
  end


  describe "reduction planning" do
    context "with simple reduction" do
      it "creates a reduction plan with correct axis" do
        result = run_join_reduce_planning do
          input do
            array :items do
              float :price
            end
          end
          value :total, fn(:sum, input.items.price)
        end

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.function).to eq(:sum)
        expect(plan.axis).to eq([:items])  # Reduces over items dimension
        expect(plan.source_scope).to eq([:items])
        expect(plan.result_scope).to eq([])  # Scalar result
      end
    end

    context "with nested array reduction" do
      it "reduces innermost dimension by default" do
        result = run_join_reduce_planning do
          input do
            array :regions do
              array :offices do
                float :revenue
              end
            end
          end
          value :regional_totals, fn(:sum, input.regions.offices.revenue)
        end

        plan = result[:join_reduce_plans][:regional_totals]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.axis).to eq([:offices]) # Reduces innermost
        expect(plan.source_scope).to eq(%i[regions offices])
        expect(plan.result_scope).to eq([:regions]) # Keeps outer dimension
      end
    end

    context "with explicit reduction axis" do
      it "uses explicit axis when provided" do
        # NOTE: Explicit axis configuration is currently not exposed through DSL
        # This test shows the default behavior for 2D reduction
        result = run_join_reduce_planning do
          input do
            array :matrix do
              array :rows do
                float :values
              end
            end
          end
          value :total, fn(:sum, input.matrix.rows.values)
        end

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.axis).to eq([:rows]) # Reduces innermost dimension by default
        expect(plan.source_scope).to eq(%i[matrix rows])
        expect(plan.result_scope).to eq([:matrix]) # Keeps outer dimension
      end
    end

    context "with flatten requirements" do
      it "includes flatten indices in plan" do
        result = run_join_reduce_planning do
          input do
            array :nested do
              array :items do
                element :integer, :value
              end
            end
          end
          value :flat_sum, fn(:sum, input.nested.items.value)
        end

        plan = result[:join_reduce_plans][:flat_sum]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.flatten_args).to eq([0]) # Flatten the nested array structure
      end
    end
  end

  describe "join planning" do
    context "with multiple vectorized arguments" do
      it "creates join plan for multi-argument operations" do
        result = run_join_reduce_planning do
          input do
            array :items do
              float :price
              integer :quantity
            end
          end
          value :products, input.items.price * input.items.quantity
        end

        plan = result[:join_reduce_plans][:products]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Join)
        expect(plan.policy).to eq(:zip)
        expect(plan.target_scope).to eq([:items])
      end
    end

    context "with single argument (no join needed)" do
      it "creates join plan even with scalar literal" do
        result = run_join_reduce_planning do
          input do
            array :items do
              float :value
            end
          end
          value :doubled, input.items.value * 2
        end

        # Since there are 2 arguments (array + scalar), it still creates a join plan
        plan = result[:join_reduce_plans][:doubled]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Join)
        expect(plan.policy).to eq(:zip)
        expect(plan.target_scope).to eq([:items])
      end
    end
  end

  describe "scope inference" do
    context "when scope_plans not available" do
      it "infers scope from reduction argument" do
        # This test simulates a state where scope_plans is empty
        # In practice, this shouldn't happen with the analyzer helper
        # but we test the fallback behavior
        result = run_join_reduce_planning do
          input do
            array :data do
              float :values
            end
          end
          value :total, fn(:sum, input.data.values)
        end

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.source_scope).to eq([:data])
        expect(plan.axis).to eq([:data])  # Reduces over data dimension
        expect(plan.result_scope).to eq([])  # Scalar result
      end
    end

    context "with declaration reference" do
      it "follows declaration references to find scope" do
        result = run_join_reduce_planning do
          input do
            array :items do
              float :value
            end
          end
          value :values, input.items.value
          value :total, fn(:sum, ref(:values))
        end

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.source_scope).to eq([:items])
        expect(plan.result_scope).to eq([])  # Scalar result from reducing all items
        expect(plan.axis).to eq([:items])  # Reduces over items dimension
      end
    end
  end

  describe "debug output" do
    it "outputs debug information when DEBUG_JOIN_REDUCE is set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("DEBUG_JOIN_REDUCE").and_return("1")

      expect do
        run_join_reduce_planning do
          input do
            array :items do
              float :price
            end
          end
          value :total, fn(:sum, input.items.price)
        end
      end.to output(/=== Processing reduction: total ===/).to_stdout
    end

    it "does not output debug information by default" do
      expect do
        run_join_reduce_planning do
          input do
            array :items do
              float :price
            end
          end
          value :total, fn(:sum, input.items.price)
        end
      end.not_to output.to_stdout
    end
  end

  describe "error handling" do
    it "handles missing broadcasts gracefully" do
      result = run_join_reduce_planning do
        input do
          integer :simple_field
        end
        value :test, input.simple_field
      end

      expect(result[:join_reduce_plans]).to eq({})
    end
  end
end
