# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::ScopeResolutionPass do
  describe "basic scope resolution" do
    context "with scalar declarations" do
      it "assigns empty scope to scalar declarations" do
        state = analyze_up_to(:scope_plans) do
          input do
            # No inputs needed for scalar literal
          end
          value :total, 100
        end

        scope_plan = state[:scope_plans][:total]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([])
        expect(scope_plan.lifts).to eq([])
        expect(scope_plan.join_hint).to be_nil
        expect(scope_plan.arg_shapes).to eq({})

        expect(state[:decl_shapes][:total]).to eq({
                                                    scope: [],
                                                    result: :scalar
                                                  })
      end
    end

    context "with vectorized operations" do
      it "determines scope from vectorization metadata" do
        state = analyze_up_to(:scope_plans) do
          input do
            array :line_items do
              float :price
              integer :quantity
            end
          end
          value :subtotals, input.line_items.price * input.line_items.quantity
        end

        scope_plan = state[:scope_plans][:subtotals]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([:line_items])

        expect(state[:decl_shapes][:subtotals]).to eq({
                                                        scope: [:line_items],
                                                        result: { array: :dense }
                                                      })
      end
    end

    context "with reduction operations" do
      it "marks reductions as scalar result" do
        state = analyze_up_to(:scope_plans) do
          input do
            array :items do
              float :price
            end
          end
          value :total, fn(:sum, input.items.price)
        end

        scope_plan = state[:scope_plans][:total]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([])

        expect(state[:decl_shapes][:total]).to eq({
                                                    scope: [],
                                                    result: :scalar # Reduction produces scalar
                                                  })
      end
    end

    context "with nested arrays" do
      it "captures nested array dimensions in scope" do
        state = analyze_up_to(:scope_plans) do
          input do
            array :regions do
              array :offices do
                float :revenue
              end
            end
          end
          value :revenues, input.regions.offices.revenue
        end

        scope_plan = state[:scope_plans][:revenues]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq(%i[regions offices])

        expect(state[:decl_shapes][:revenues]).to eq({
                                                       scope: %i[regions offices],
                                                       result: { array: :dense }
                                                     })
      end
    end

    context "with cascade expressions" do
      it "derives scope from first input path in cascade" do
        state = analyze_up_to(:scope_plans) do
          input do
            array :orders do
              boolean :urgent
            end
          end
          trait :is_urgent, input.orders.urgent == true
          value :statuses do
            on is_urgent, "URGENT"
            base "NORMAL"
          end
        end

        scope_plan = state[:scope_plans][:statuses]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([:orders])

        expect(state[:decl_shapes][:statuses]).to eq({
                                                       scope: [:orders],
                                                       result: { array: :dense }
                                                     })
      end
    end
  end

  describe "error handling" do
    context "with invalid schema constructions" do
      it "handles errors through the analyzer pipeline" do
        expect do
          analyze_up_to(:scope_plans) do
            input do
              # Invalid schema will be caught by earlier passes
            end
            value :invalid, ref(:nonexistent)
          end
        end.to raise_error(Kumi::Errors::AnalysisError)
      end
    end
  end
end
