# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Incremental Updates" do
  describe "#update method" do
    let(:result) { run_schema_fixture("incremental_updates", input_data: input_data) }

    let(:input_data) do
      {
        base_value: 10,
        multiplier: 3,
        label: "Result"
      }
    end

    it "supports updating input values" do
      expect(result[:computed_value]).to eq(30)
      expect(result[:status]).to eq("LOW")

      # Update just the multiplier
      updated_result = result.update(multiplier: 5)

      expect(updated_result[:computed_value]).to eq(50)
      expect(updated_result[:status]).to eq("LOW")
      expect(updated_result[:independent_value]).to eq(20) # Should remain unchanged
    end

    it "returns the same object for chaining" do
      updated_result = result.update(base_value: 20)
      expect(updated_result).to be(result)
    end

    it "handles multiple updates" do
      result.update(base_value: 15, multiplier: 4)

      expect(result[:computed_value]).to eq(60)
      expect(result[:status]).to eq("HIGH")
      expect(result[:display_text]).to eq("Result: 60")
    end

    it "only recalculates affected values" do
      # Cache some values first
      initial_computed = result[:computed_value]
      result[:display_text]

      result.update(label: "New Label")

      # Should only affect display_text, not computed_value or status
      expect(result[:display_text]).to eq("New Label: 30") # Updated
      expect(result[:computed_value]).to eq(initial_computed) # Same value as before
      expect(result[:status]).to eq("LOW") # Should remain the same
    end
  end

  describe "dependency tracking" do
    let(:runner) do
      build_schema do
        input do
          integer :a
          integer :b
          integer :c
        end

        value :step1, fn(:add, input.a, input.b)
        value :step2, fn(:multiply, step1, 2)
        value :step3, fn(:add, step2, input.c)
        value :independent, fn(:multiply, input.c, 3)
      end
    end

    let(:result) { runner.from(a: 1, b: 2, c: 5) }

    it "tracks transitive dependencies correctly" do
      expect(result[:step3]).to eq(11) # ((1+2) * 2) + 5

      # Updating 'a' should affect step1, step2, and step3, but not independent
      result.update(a: 10)

      expect(result[:step3]).to eq(29) # ((10+2) * 2) + 5
      expect(result[:independent]).to eq(15) # Should remain 5 * 3

      # Verify all intermediate values are also updated correctly
      expect(result[:step1]).to eq(12) # 10 + 2
      expect(result[:step2]).to eq(24) # 12 * 2
    end
  end

  describe "trait dependencies" do
    let(:runner) do
      build_schema do
        input do
          integer :score
          string :grade
        end

        trait :passing, input.score, :>=, 70
        trait :honor_roll, input.score, :>=, 90

        value :status do
          on honor_roll, "HONORS"
          on passing, "PASS"
          base "FAIL"
        end

        value :certificate do
          on honor_roll, "Gold Certificate"
          on passing, "Standard Certificate"
          base "No Certificate"
        end

        value :unrelated, fn(:concat, input.grade, " Grade")
      end
    end

    let(:result) { runner.from(score: 85, grade: "A") }

    it "recalculates trait-dependent values when traits change" do
      expect(result[:status]).to eq("PASS")
      expect(result[:certificate]).to eq("Standard Certificate")

      result.update(score: 95)

      expect(result[:status]).to eq("HONORS")
      expect(result[:certificate]).to eq("Gold Certificate")
      expect(result[:unrelated]).to eq("A Grade") # Should remain unchanged
    end
  end

  describe "performance considerations" do
    let(:expensive_schema) do
      build_schema do
        input do
          integer :base
          integer :factor
          integer :unrelated
        end

        # Simulate expensive computation
        value :expensive_calc, fn(:multiply, fn(:multiply, input.base, input.factor), 1000)

        value :dependent_on_expensive, fn(:add, expensive_calc, 1)
        value :independent_calc, fn(:add, input.unrelated, 100)
      end
    end

    xit "with selective cache clearing (default), only recalculates affected values" do
      # update to Program and Session to support []
    end

    it "with simple cache clearing fallback, recalculates all values", if: ENV["KUMI_SIMPLE_CACHE"] == "true" do
      result = expensive_schema.from(base: 5, factor: 2, unrelated: 50)

      expect(result[:expensive_calc]).to eq(10_000)
      expect(result[:independent_calc]).to eq(150)

      # Update input - this clears all cached values in simple mode
      result.update(unrelated: 60)

      expect(result[:expensive_calc]).to eq(10_000) # Recalculated (cache cleared)
      expect(result[:independent_calc]).to eq(160) # Also recalculated
    end
  end

  describe "error handling" do
    let(:runner) do
      build_schema do
        input do
          integer :value, domain: 1..100
        end

        value :computed, fn(:multiply, input.value, 2)
      end
    end

    let(:result) { runner.from(value: 50) }

    xit "validates updated values against domain constraints" do
      expect do
        result.update(value: 150) # Outside domain
      end.to raise_error(ArgumentError, /value 150 is not in domain 1\.\.100/)
    end

    xit "handles updating non-existent fields" do
      expect do
        result.update(nonexistent_field: 42)
      end.to raise_error(ArgumentError, /unknown input field: nonexistent_field/)
    end
  end

  describe "complex scenario: configuration system" do
    let(:result) { run_schema_fixture("theme_configuration", input_data: {}) }

    it "handles realistic incremental configuration updates" do
      theme = result.update(
        primary_color: "#3366cc",
        secondary_color: "#66cc33",
        font_size: 14,
        dark_mode: false
      )

      expect(theme[:accent_color]).to eq("#3366cc-dark")
      expect(theme[:text_color]).to eq("#000000")

      # User toggles dark mode - should update accent_color, text_color, and css_vars
      theme.update(dark_mode: true)

      expect(theme[:accent_color]).to eq("#3366cc-light")
      expect(theme[:text_color]).to eq("#ffffff")
      expect(theme[:css_vars]).to include("--accent: #3366cc-light")
      expect(theme[:css_vars]).to include("--text: #ffffff")

      # # User changes primary color - should update accent_color and css_vars
      # css_vars: "--primary: #3366cc; --accent: #3366cc-light; --text: #ffffff; --font-size: 14px;" }
      theme.update(primary_color: "#cc3366")
      # css_vars: "--primary: #3366cc; --accent: #3366cc-light; --text: #ffffff; --font-size: 14px;" }

      expect(theme[:accent_color]).to eq("#cc3366-light")
      expect(theme[:css_vars]).to include("--primary: #cc3366")
      expect(theme[:css_vars]).to include("--accent: #cc3366-light")
    end
  end
end
