# frozen_string_literal: true

module PassTestHelper
  # Helper to run a single pass and get the result state
  # Usage:
  #   state = run_pass(NameIndexerPass) do
  #     input do
  #       integer :x
  #     end
  #     value :double, input.x * 2
  #   end
  def run_pass(pass_class, initial_state = nil, &)
    syntax_tree = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&)
    state = initial_state || Kumi::Core::Analyzer::AnalysisState.new
    errors = []

    pass_instance = pass_class.new(syntax_tree, state)
    result_state = pass_instance.run(errors)

    {
      state: result_state,
      errors: errors,
      success?: errors.empty?
    }
  end

  # Helper to run multiple passes in sequence
  # Usage:
  #   result = run_passes([NameIndexerPass, InputCollectorPass]) do
  #     input do
  #       array :items do
  #         float :price
  #       end
  #     end
  #     value :total, fn(:sum, input.items.price)
  #   end
  def run_passes(pass_classes, &)
    syntax_tree = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&)
    state = Kumi::Core::Analyzer::AnalysisState.new
    errors = []

    pass_classes.each do |pass_class|
      pass_instance = pass_class.new(syntax_tree, state)
      state = pass_instance.run(errors)
      break unless errors.empty? # Stop on first error
    end

    {
      state: state,
      errors: errors,
      success?: errors.empty?
    }
  end

  # Helper to assert pass succeeded with no errors
  # Usage:
  #   result = run_pass(NameIndexerPass) { ... }
  #   expect_pass_success(result)
  def expect_pass_success(result)
    expect(result[:success?]).to be true, "Pass failed with errors: #{result[:errors].map(&:to_s).join(', ')}"
    expect(result[:errors]).to be_empty
    result[:state]
  end

  # Helper to assert pass failed with errors
  # Usage:
  #   result = run_pass(NameIndexerPass) { ... }
  #   expect_pass_errors(result, count: 1, message: /duplicate/)
  def expect_pass_errors(result, count: nil, message: nil)
    expect(result[:success?]).to be false
    expect(result[:errors]).not_to be_empty

    expect(result[:errors].size).to eq(count) if count

    if message
      messages = result[:errors].map(&:message).join(", ")
      expect(messages).to match(message)
    end

    result[:errors]
  end

  # Helper to assert specific state keys exist after pass
  # Usage:
  #   result = run_pass(NameIndexerPass) { ... }
  #   expect_state_keys(result, :declarations)
  def expect_state_keys(result, *keys)
    state = result[:state]
    keys.each do |key|
      expect(state).to have_key(key), "State missing key #{key.inspect}"
    end
  end
end

RSpec.configure do |config|
  config.include PassTestHelper
end
