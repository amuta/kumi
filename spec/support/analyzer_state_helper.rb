# frozen_string_literal: true

module AnalyzerStateHelper
  # Helper to run analyzer passes up to a certain point and get the state
  # Usage:
  #   state = analyze_up_to(:broadcasts) do
  #     input do
  #       array :items do
  #         float :price
  #       end
  #     end
  #     value :total, fn(:sum, input.items.price)
  #   end
  #
  #   state[:broadcasts] # => broadcasts metadata
  def analyze_up_to(target_state, &schema_block)
    syntax_tree = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&schema_block)

    # Map state names to pass indices
    state_to_pass = {
      name_index: 0,           # NameIndexer
      input_metadata: 1,       # InputCollector
      declarations: 1,         # InputCollector also produces declarations
      validated: 2,            # DeclarationValidator
      semantic_valid: 3,       # SemanticConstraintValidator
      dependencies: 4,         # DependencyResolver
      unsat_detected: 5,       # UnsatDetector
      evaluation_order: 6,     # Toposorter
      cascade_validated: 7,    # CascadeConstraintValidator
      cascade_desugared: 8,    # CascadeDesugarPass
      call_normalized: 9,      # CallNameNormalizePass
      broadcasts: 10,          # BroadcastDetector
      types_inferred: 11,      # TypeInferencerPass
      types_consistent: 12,    # TypeConsistencyChecker
      function_signatures: 13, # FunctionSignaturePass
      types_checked: 14,       # TypeChecker
      ambiguity_resolved: 15,  # AmbiguityResolverPass
      access_plans: 16,        # InputAccessPlannerPass
      scope_plans: 17,         # ScopeResolutionPass
      join_reduce_plans: 18,   # JoinReducePlanningPass
      ir_module: 19            # LowerToIRPass
    }

    target_pass_index = state_to_pass[target_state]
    raise ArgumentError, "Unknown state: #{target_state}. Available: #{state_to_pass.keys.join(', ')}" unless target_pass_index

    # Get the passes to run
    passes = Kumi::Analyzer::DEFAULT_PASSES[0..target_pass_index]

    # Run analysis with selected passes
    state = Kumi::Core::Analyzer::AnalysisState.new({})
    registry = Kumi::Core::Functions::RegistryV2.load_from_file
    state = state.with(:registry, registry)
    errors = []

    passes.each do |pass_class|
      pass_instance = pass_class.new(syntax_tree, state)
      state = pass_instance.run(errors)

      raise Kumi::Errors::AnalysisError, "Analysis failed: #{errors.map(&:to_s).join(', ')}" unless errors.empty?
    end

    state
  end

  # Helper to get a specific state value directly
  # Usage:
  #   broadcasts = get_analyzer_state(:broadcasts) do
  #     input do
  #       array :items do
  #         float :price
  #       end
  #     end
  #     value :total, fn(:sum, input.items.price)
  #   end
  def get_analyzer_state(state_name, &)
    state = analyze_up_to(state_name, &)
    state[state_name]
  end

  # Helper to inspect multiple states at once
  # Usage:
  #   states = inspect_analyzer_states([:input_metadata, :broadcasts]) do
  #     input do
  #       array :items do
  #         float :price
  #       end
  #     end
  #     value :total, fn(:sum, input.items.price)
  #   end
  def inspect_analyzer_states(state_names, &)
    # Find the latest state we need
    state_order = %i[name_index input_metadata declarations validated semantic_valid
                     dependencies unsat_detected evaluation_order cascade_validated
                     cascade_desugared call_normalized broadcasts types_inferred
                     types_consistent function_signatures types_checked ambiguity_resolved
                     access_plans scope_plans join_reduce_plans ir_module]

    latest_index = state_names.map { |s| state_order.index(s) }.compact.max
    latest_state = state_order[latest_index]

    final_state = analyze_up_to(latest_state, &)

    result = {}
    state_names.each do |name|
      result[name] = final_state[name]
    end
    result
  end

  # Helper to get the syntax tree without running analysis
  # Usage:
  #   tree = build_syntax_tree do
  #     input do
  #       integer :x
  #     end
  #     value :double, input.x * 2
  #   end
  def build_syntax_tree(&)
    Kumi::Core::RubyParser::Dsl.build_syntax_tree(&)
  end

  # Helper to run analysis with custom passes
  # Usage:
  #   state = analyze_with_passes([Kumi::Core::Analyzer::Passes::NameIndexer]) do
  #     input do
  #       integer :x
  #     end
  #   end
  def analyze_with_passes(passes, &schema_block)
    syntax_tree = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&schema_block)

    state = Kumi::Core::Analyzer::AnalysisState.new({})
    errors = []

    passes.each do |pass_class|
      pass_instance = pass_class.new(syntax_tree, state)
      state = pass_instance.run(errors)

      raise Kumi::Errors::AnalysisError, "Analysis failed: #{errors.map(&:to_s).join(', ')}" unless errors.empty?
    end

    state
  end

  # Helper to print analyzer state in a readable format
  # Usage:
  #   print_analyzer_state(:broadcasts) do
  #     input do
  #       array :items do
  #         float :price
  #       end
  #     end
  #     value :total, fn(:sum, input.items.price)
  #   end
  def print_analyzer_state(state_name, &)
    state_value = get_analyzer_state(state_name, &)

    puts "=== Analyzer State: #{state_name} ==="
    pp state_value
    puts "=" * 50

    state_value
  end
end

# Include in RSpec if loaded in test environment
if defined?(RSpec)
  RSpec.configure do |config|
    config.include AnalyzerStateHelper
  end
end
