# frozen_string_literal: true

# Helper to make accessing the strategy variable easier
module StrategyTestHelper
  def build_accessors_with_strategy(plans, **options)
    Kumi::Core::Compiler::AccessBuilder.build(plans, **options, strategy: strategy)
  end
end

# Extend the context class to support test_both_strategies at the describe/context level
module StrategyContextHelper
  def test_both_strategies(&block)
    %i[interp codegen].each do |strategy_name|
      context "with #{strategy_name} strategy" do
        let(:strategy) { strategy_name }

        instance_eval(&block)
      end
    end
  end
end

RSpec.configure do |config|
  config.include StrategyTestHelper
  config.extend StrategyContextHelper
end
