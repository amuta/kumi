# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::JoinReducePlanningPass do
  let(:errors) { [] }
  let(:schema) { Kumi::Syntax::Root.new }

  def run_pass(initial_state)
    state = Kumi::Core::Analyzer::AnalysisState.new(initial_state)
    registry = Kumi::Core::Functions::RegistryV2.load_from_file
    state = state.with(:registry, registry)
    described_class.new(schema, state).run(errors)
  end

  # Helper methods
  def value_decl(name, expr)
    Kumi::Syntax::ValueDeclaration.new(name, expr)
  end

  def literal(value)
    Kumi::Syntax::Literal.new(value)
  end

  def input_element_ref(path)
    Kumi::Syntax::InputElementReference.new(path)
  end

  def call_expr(fn_name, *args)
    Kumi::Syntax::CallExpression.new(fn_name, args)
  end

  def declaration_ref(name)
    Kumi::Syntax::DeclarationReference.new(name)
  end

  # Helper to build node_index for CallExpression nodes
  def build_node_index(*call_nodes)
    index = {}
    call_nodes.each do |call|
      index[call.object_id] = {
        type: "CallExpression",
        node: call,
        metadata: {
          qualified_name: "agg.#{call.fn_name}",
          fn_class: :aggregate,
          selected_signature: "test_signature"
        }
      }
    end
    index
  end

  describe "reduction planning" do
    context "with simple reduction" do
      let(:sum_call) { call_expr(:sum, input_element_ref([:items, :price])) }
      let(:initial_state) do
        {
          declarations: {
            total: value_decl(:total, sum_call)
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
            reduction_operations: {
              total: {
                function: :sum,
                argument: input_element_ref([:items, :price])
              }
            }
          },
          scope_plans: {
            total: Kumi::Core::Analyzer::Plans::Scope.new(scope: [])
          },
          node_index: build_node_index(sum_call)
        }
      end

      it "creates a reduction plan with correct axis" do
        result = run_pass(initial_state)

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.function).to eq(:sum)
        expect(plan.axis).to eq([:items])
        expect(plan.source_scope).to eq([:items])
        expect(plan.result_scope).to eq([])
      end
    end

    context "with nested array reduction" do
      let(:nested_sum_call) { call_expr(:sum, input_element_ref([:regions, :offices, :revenue])) }
      let(:initial_state) do
        {
          declarations: {
            regional_totals: value_decl(:regional_totals, nested_sum_call)
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
            reduction_operations: {
              regional_totals: {
                function: :sum,
                argument: input_element_ref([:regions, :offices, :revenue])
              }
            }
          },
          scope_plans: {
            regional_totals: Kumi::Core::Analyzer::Plans::Scope.new(scope: [:regions])
          },
          node_index: build_node_index(nested_sum_call)
        }
      end

      it "reduces innermost dimension by default" do
        result = run_pass(initial_state)

        plan = result[:join_reduce_plans][:regional_totals]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.axis).to eq([:offices])  # Reduces innermost
        expect(plan.source_scope).to eq([:regions, :offices])
        expect(plan.result_scope).to eq([:regions])  # Keeps outer dimension
      end
    end

    context "with explicit reduction axis" do
      let(:matrix_sum_call) { call_expr(:sum, input_element_ref([:matrix, :rows, :values])) }
      let(:initial_state) do
        {
          declarations: {
            total: value_decl(:total, matrix_sum_call)
          },
          input_metadata: {
            matrix: {
              type: :array,
              children: {
                rows: {
                  type: :array,
                  children: {
                    values: { type: :float }
                  }
                }
              }
            }
          },
          broadcasts: {
            reduction_operations: {
              total: {
                function: :sum,
                argument: input_element_ref([:matrix, :rows, :values]),
                axis: :all  # Reduce all dimensions
              }
            }
          },
          scope_plans: {
            total: Kumi::Core::Analyzer::Plans::Scope.new(scope: [:matrix, :rows])
          },
          node_index: build_node_index(matrix_sum_call)
        }
      end

      it "uses explicit axis when provided" do
        result = run_pass(initial_state)

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.axis).to eq(:all)
        expect(plan.result_scope).to eq([])  # All dimensions reduced
      end
    end

    context "with flatten requirements" do
      let(:initial_state) do
        {
          declarations: {
            flat_sum: value_decl(:flat_sum,
              call_expr(:sum, input_element_ref([:nested, :items]))
            )
          },
          input_metadata: {
            nested: {
              type: :array,
              children: {
                items: { type: :array, elem: { type: :integer } }
              }
            }
          },
          broadcasts: {
            reduction_operations: {
              flat_sum: {
                function: :sum,
                argument: input_element_ref([:nested, :items]),
                flatten_argument_indices: [0]
              }
            }
          },
          scope_plans: {
            flat_sum: Kumi::Core::Analyzer::Plans::Scope.new(scope: [:nested])
          }
        }
      end

      it "includes flatten indices in plan" do
        result = run_pass(initial_state)

        plan = result[:join_reduce_plans][:flat_sum]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.flatten_args).to eq([0])
      end
    end
  end

  describe "join planning" do
    context "with multiple vectorized arguments" do
      let(:initial_state) do
        {
          declarations: {
            products: value_decl(:products,
              call_expr(:multiply,
                input_element_ref([:items, :price]),
                input_element_ref([:items, :quantity])
              )
            )
          },
          input_metadata: {
            items: {
              type: :array,
              children: {
                price: { type: :float },
                quantity: { type: :integer }
              }
            }
          },
          broadcasts: {
            vectorized_operations: {
              products: {
                source: :nested_array_access,
                path: [:items, :price]
              }
            }
          },
          scope_plans: {
            products: Kumi::Core::Analyzer::Plans::Scope.new(scope: [:items])
          }
        }
      end

      it "creates join plan for multi-argument operations" do
        result = run_pass(initial_state)

        plan = result[:join_reduce_plans][:products]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Join)
        expect(plan.policy).to eq(:zip)
        expect(plan.target_scope).to eq([:items])
      end
    end

    context "with single argument (no join needed)" do
      let(:initial_state) do
        {
          declarations: {
            doubled: value_decl(:doubled,
              call_expr(:multiply,
                input_element_ref([:items, :value]),
                literal(2)
              )
            )
          },
          input_metadata: {
            items: {
              type: :array,
              children: {
                value: { type: :float }
              }
            }
          },
          broadcasts: {
            vectorized_operations: {
              doubled: {
                source: :nested_array_access,
                path: [:items, :value]
              }
            }
          },
          scope_plans: {
            doubled: Kumi::Core::Analyzer::Plans::Scope.new(scope: [:items])
          }
        }
      end

      it "creates join plan even with scalar literal" do
        result = run_pass(initial_state)

        # Since there are 2 arguments (array + scalar), it still creates a join plan
        plan = result[:join_reduce_plans][:doubled]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Join)
      end
    end
  end

  describe "scope inference" do
    context "when scope_plans not available" do
      let(:initial_state) do
        {
          declarations: {
            total: value_decl(:total,
              call_expr(:sum, input_element_ref([:data, :values]))
            )
          },
          input_metadata: {
            data: {
              type: :array,
              children: {
                values: { type: :float }
              }
            }
          },
          broadcasts: {
            reduction_operations: {
              total: {
                function: :sum,
                argument: input_element_ref([:data, :values])
              }
            }
          },
          scope_plans: {}  # No scope plans available
        }
      end

      it "infers scope from reduction argument" do
        result = run_pass(initial_state)

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.source_scope).to eq([:data])
        expect(plan.result_scope).to eq([])
      end
    end

    context "with declaration reference" do
      let(:initial_state) do
        {
          declarations: {
            values: value_decl(:values, input_element_ref([:items, :value])),
            total: value_decl(:total, call_expr(:sum, declaration_ref(:values)))
          },
          input_metadata: {
            items: {
              type: :array,
              children: {
                value: { type: :float }
              }
            }
          },
          broadcasts: {
            reduction_operations: {
              total: {
                function: :sum,
                argument: declaration_ref(:values)
              }
            }
          },
          scope_plans: {}
        }
      end

      it "follows declaration references to find scope" do
        result = run_pass(initial_state)

        plan = result[:join_reduce_plans][:total]
        expect(plan).to be_a(Kumi::Core::Analyzer::Plans::Reduce)
        expect(plan.source_scope).to eq([:items])
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
        broadcasts: {
          reduction_operations: {
            test: { function: :sum, argument: literal(42) }
          }
        },
        scope_plans: {}
      }
    end

    it "outputs debug information when DEBUG_JOIN_REDUCE is set" do
      allow(ENV).to receive(:[]).with("DEBUG_JOIN_REDUCE").and_return("true")

      expect { run_pass(initial_state) }.to output(/=== Processing reduction: test ===/).to_stdout
    end

    it "does not output debug information by default" do
      expect { run_pass(initial_state) }.not_to output.to_stdout
    end
  end

  describe "error handling" do
    it "handles missing broadcasts gracefully" do
      result = run_pass({
        declarations: {},
        input_metadata: {},
        node_index: {}
      })

      expect(result[:join_reduce_plans]).to eq({})
    end

    it "requires declarations" do
      expect {
        run_pass({ input_metadata: {}, node_index: {} })
      }.to raise_error(StandardError, /Required state key 'declarations' not found/)
    end

    it "requires input_metadata" do
      expect {
        run_pass({ declarations: {}, node_index: {} })
      }.to raise_error(StandardError, /Required state key 'input_metadata' not found/)
    end
  end
end