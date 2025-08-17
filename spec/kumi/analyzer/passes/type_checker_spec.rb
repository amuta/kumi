# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::TypeCheckerV2 do
  include AnalyzerStateHelper

  def run_type_checker_for_schema(&schema_block)
    errors = []
    begin
      syntax_tree = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&schema_block)
      
      # Initialize state with registry (similar to main analyzer)
      state = Kumi::Core::Analyzer::AnalysisState.new({})
      registry = Kumi::Core::Functions::RegistryV2.load_from_file
      state = state.with(:registry, registry)

      # Get the passes to run up to TypeCheckerV2
      passes = Kumi::Analyzer::DEFAULT_PASSES[0..14] # Up to TypeCheckerV2

      # Run analysis with selected passes
      passes.each do |pass_class|
        pass_instance = pass_class.new(syntax_tree, state)
        state = pass_instance.run(errors)
        break unless errors.empty? # Stop on first error for cleaner test output
      end

      errors
    rescue => e
      # Convert any exception to error format for consistency
      [OpenStruct.new(message: e.message)]
    end
  end

  describe ".run" do
    context "when operator arity mismatch" do
      it "records a signature mismatch error" do
        errors = run_type_checker_for_schema do
          trait :bad, fn(:>, 1)
        end
        expect(errors.first.message).to match(/Function `core.gt` signature mismatch/)
      end
    end

    context "when operator type mismatch" do
      it "records a type error for the mismatched argument" do
        errors = run_type_checker_for_schema do
          trait :bad, fn(:>, 1, "test")
        end
        expect(errors.first.message).to match(/argument 2 of `fn\(:>\)` expects float, got/)
      end
    end

    context "when a function call is valid" do
      it "completes with no errors" do
        errors = run_type_checker_for_schema do
          trait :valid, fn(:>=, 10, 5)
        end
        expect(errors).to be_empty
      end
    end

    context "when aggregate functions are called with array inputs" do
      context "with valid numeric element types" do
        it "completes with no errors for float arrays" do
          errors = run_type_checker_for_schema do
            input do
              array :items, elem: { type: :float }
            end
            value :total, fn(:sum, input.items)
          end
          expect(errors).to be_empty
        end

        it "completes with no errors for integer arrays" do
          errors = run_type_checker_for_schema do
            input do
              array :items, elem: { type: :integer }
            end
            value :total, fn(:sum, input.items)
          end
          expect(errors).to be_empty
        end
      end

      context "with invalid non-numeric element types" do
        it "records a type error for non-numeric element types" do
          errors = run_type_checker_for_schema do
            input do
              array :items, elem: { type: :string }
            end
            value :total, fn(:sum, input.items)
          end
          expect(errors.first.message).to match(/argument 1 of `fn\(:sum\)` expects float, got/)
        end
      end
    end

    context "when scalar functions are called with array inputs" do
      it "records a signature mismatch error for scalar functions with array inputs" do
        errors = run_type_checker_for_schema do
          input do
            array :items, elem: { type: :float }
          end
          value :bad_total, fn(:add, input.items)
        end
        expect(errors.first.message).to match(/Function `core.add` signature mismatch/)
      end
    end

    context "when aggregate functions are called in cascade conditions" do
      it "validates aggregate functions correctly inside cascade expressions" do
        errors = run_type_checker_for_schema do
          input do
            array :items, elem: { type: :float }
          end
          trait :has_items, fn(:>, fn(:sum, input.items), 0)
          value :status do
            on has_items, "has items"
            base "empty"
          end
        end
        expect(errors).to be_empty
      end
    end
  end
end
