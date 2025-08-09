# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::ScopeResolutionPass do
  let(:errors) { [] }
  let(:schema) { Kumi::Syntax::Root.new }
  
  def run_pass(initial_state)
    state = Kumi::Core::Analyzer::AnalysisState.new(initial_state)
    described_class.new(schema, state).run(errors)
  end
  
  # Helper to create a simple value declaration
  def value_decl(name, expr)
    Kumi::Syntax::ValueDeclaration.new(name, expr)
  end
  
  # Helper to create literal
  def literal(value)
    Kumi::Syntax::Literal.new(value)
  end
  
  # Helper to create input element reference
  def input_element_ref(path)
    Kumi::Syntax::InputElementReference.new(path)
  end
  
  # Helper to create call expression
  def call_expr(fn_name, *args)
    Kumi::Syntax::CallExpression.new(fn_name, args)
  end
  
  # Helper to create cascade
  def cascade_expr(cases)
    Kumi::Syntax::CascadeExpression.new(cases)
  end
  
  # Helper to create case expression
  def case_expr(condition, result)
    Kumi::Syntax::CaseExpression.new(condition, result)
  end

  describe "basic scope resolution" do
    context "with scalar declarations" do
      let(:initial_state) do
        {
          declarations: {
            total: value_decl(:total, literal(100))
          },
          input_metadata: {},
          broadcasts: {}
        }
      end

      it "assigns empty scope to scalar declarations" do
        result = run_pass(initial_state)
        
        scope_plan = result[:scope_plans][:total]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([])
        expect(scope_plan.lifts).to eq([])
        expect(scope_plan.join_hint).to be_nil
        expect(scope_plan.arg_shapes).to eq({})
        
        expect(result[:decl_shapes][:total]).to eq({
          scope: [],
          result: :scalar
        })
      end
    end

    context "with vectorized operations" do
      let(:initial_state) do
        {
          declarations: {
            subtotals: value_decl(:subtotals, 
              call_expr(:multiply, 
                input_element_ref([:line_items, :price]),
                input_element_ref([:line_items, :quantity])
              )
            )
          },
          input_metadata: {
            line_items: {
              type: :array,
              children: {
                price: { type: :float },
                quantity: { type: :integer }
              }
            }
          },
          broadcasts: {
            vectorized_operations: {
              subtotals: {
                source: :nested_array_access,
                path: [:line_items, :price]
              }
            }
          }
        }
      end

      it "determines scope from vectorization metadata" do
        result = run_pass(initial_state)
        
        scope_plan = result[:scope_plans][:subtotals]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([:line_items])
        
        expect(result[:decl_shapes][:subtotals]).to eq({
          scope: [:line_items],
          result: { array: :dense }
        })
      end
    end

    context "with reduction operations" do
      let(:initial_state) do
        {
          declarations: {
            total: value_decl(:total,
              call_expr(:sum, input_element_ref([:items, :price]))
            )
          },
          input_metadata: {
            items: {
              type: :array,
              children: {
                price: { type: :float }
              }
            }
          },
          broadcasts: {
            vectorized_operations: {
              total: {
                source: :nested_array_access,
                path: [:items, :price]
              }
            },
            reduction_operations: {
              total: {
                function: :sum,
                argument: input_element_ref([:items, :price])
              }
            }
          }
        }
      end

      it "marks reductions as scalar result" do
        result = run_pass(initial_state)
        
        scope_plan = result[:scope_plans][:total]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([:items])
        
        expect(result[:decl_shapes][:total]).to eq({
          scope: [:items],
          result: :scalar  # Reduction produces scalar
        })
      end
    end

    context "with nested arrays" do
      let(:initial_state) do
        {
          declarations: {
            revenues: value_decl(:revenues,
              input_element_ref([:regions, :offices, :revenue])
            )
          },
          input_metadata: {
            regions: {
              type: :array,
              children: {
                offices: {
                  type: :array,
                  children: {
                    revenue: { type: :float }
                  }
                }
              }
            }
          },
          broadcasts: {
            vectorized_operations: {
              revenues: {
                source: :nested_array_access,
                path: [:regions, :offices, :revenue]
              }
            }
          }
        }
      end

      it "captures nested array dimensions in scope" do
        result = run_pass(initial_state)
        
        scope_plan = result[:scope_plans][:revenues]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([:regions, :offices])
        
        expect(result[:decl_shapes][:revenues]).to eq({
          scope: [:regions, :offices],
          result: { array: :dense }
        })
      end
    end

    context "with cascade expressions" do
      let(:initial_state) do
        {
          declarations: {
            statuses: value_decl(:statuses,
              cascade_expr([
                case_expr(input_element_ref([:orders, :urgent]), literal("URGENT")),
                case_expr(nil, literal("NORMAL"))
              ])
            )
          },
          input_metadata: {
            orders: {
              type: :array,
              children: {
                urgent: { type: :boolean }
              }
            }
          },
          broadcasts: {
            vectorized_operations: {
              statuses: {
                source: :cascade_with_vectorized_conditions_or_results,
                path: nil
              }
            }
          }
        }
      end

      it "derives scope from first input path in cascade" do
        result = run_pass(initial_state)
        
        scope_plan = result[:scope_plans][:statuses]
        expect(scope_plan).to be_a(Kumi::Core::Analyzer::Plans::Scope)
        expect(scope_plan.scope).to eq([:orders])
        
        expect(result[:decl_shapes][:statuses]).to eq({
          scope: [:orders],
          result: { array: :dense }
        })
      end
    end
  end

  describe "error handling" do
    context "with missing required state" do
      it "raises error when declarations are missing" do
        expect {
          run_pass({ input_metadata: {} })
        }.to raise_error(StandardError, /Required state key 'declarations' not found/)
      end

      it "raises error when input_metadata is missing" do
        expect {
          run_pass({ declarations: {} })
        }.to raise_error(StandardError, /Required state key 'input_metadata' not found/)
      end
    end
  end

  describe "debug output" do
    let(:initial_state) do
      {
        declarations: {
          test: value_decl(:test, literal(42))
        },
        input_metadata: {},
        broadcasts: {}
      }
    end

    it "outputs debug information when DEBUG_SCOPE_RESOLUTION is set" do
      allow(ENV).to receive(:[]).with("DEBUG_SCOPE_RESOLUTION").and_return("true")
      
      expect { run_pass(initial_state) }.to output(/=== Resolving scope for test ===/).to_stdout
    end

    it "does not output debug information by default" do
      expect { run_pass(initial_state) }.not_to output.to_stdout
    end
  end
end