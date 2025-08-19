# frozen_string_literal: true

module PreLowerHelper
  # Run the analyzer passes up to (and including) JoinReducePlanningPass,
  # skipping LowerToIR. This lets us test dimensional invariants before Lower.
  def analyze_until_join_reduce(schema_block, data = {})
    # Use the existing AnalyzerStateHelper to run up to join_reduce_plans
    # which corresponds to JoinReducePlanningPass (pass #18 in the index)
    analyze_up_to(:join_reduce_plans, &schema_block)
  end
end