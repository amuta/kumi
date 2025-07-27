# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Incremental Updates" do
  describe "#update method" do
    let(:schema_result) do
      build_schema do
        input do
          integer :base_value, domain: 1..100
          integer :multiplier, domain: 1..10
          string :label
        end

        value :computed_value, fn(:multiply, input.base_value, input.multiplier)
        value :display_text, fn(:concat, input.label, ": ", computed_value)
        value :independent_value, fn(:add, input.base_value, 10)

        trait :high_value, fn(:>, computed_value, 50)

        value :status do
          on high_value, "HIGH"
          base "LOW"
        end
      end
    end

    let(:initial_data) do
      {
        base_value: 10,
        multiplier: 3,
        label: "Result"
      }
    end

    let(:result) { schema_result.from(initial_data) }

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
    let(:schema_result) do
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

    let(:result) { schema_result.from(a: 1, b: 2, c: 5) }

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
    let(:schema_result) do
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

    let(:result) { schema_result.from(score: 85, grade: "A") }

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

    it "with selective cache clearing (default), only recalculates affected values" do
      result = expensive_schema.from(base: 5, factor: 2, unrelated: 50)

      # Prime the cache by accessing values
      expect(result[:expensive_calc]).to eq(10_000)
      expect(result[:independent_calc]).to eq(150)

      # Spy on the compiled bindings to track actual function calls
      compiled_schema = result.compiled_schema
      expensive_binding = compiled_schema.bindings[:expensive_calc][1]
      independent_binding = compiled_schema.bindings[:independent_calc][1]

      allow(expensive_binding).to receive(:call).and_call_original
      allow(independent_binding).to receive(:call).and_call_original

      # Update something that doesn't affect expensive_calc
      result.update(unrelated: 60)

      # Access the values to trigger evaluation
      expect(result[:expensive_calc]).to eq(10_000) # Should use cached value
      expect(result[:independent_calc]).to eq(160) # Should recalculate

      # Verify expensive_calc wasn't recalculated but independent_calc was
      expect(expensive_binding).not_to have_received(:call)
      expect(independent_binding).to have_received(:call).once
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
    let(:schema_result) do
      build_schema do
        input do
          integer :value, domain: 1..100
        end

        value :computed, fn(:multiply, input.value, 2)
      end
    end

    let(:result) { schema_result.from(value: 50) }

    it "validates updated values against domain constraints" do
      expect do
        result.update(value: 150) # Outside domain
      end.to raise_error(ArgumentError, /value 150 is not in domain 1\.\.100/)
    end

    it "handles updating non-existent fields" do
      expect do
        result.update(nonexistent_field: 42)
      end.to raise_error(ArgumentError, /unknown input field: nonexistent_field/)
    end
  end

  describe "complex scenario: configuration system" do
    let(:theme_schema) do
      build_schema do
        input do
          string :primary_color
          string :secondary_color
          integer :font_size, domain: 8..72
          boolean :dark_mode
        end

        trait :is_dark_mode, input.dark_mode, :==, true

        value :accent_color do
          on is_dark_mode, fn(:concat, input.primary_color, "-light")
          base fn(:concat, input.primary_color, "-dark")
        end

        value :text_color do
          on is_dark_mode, "#ffffff"
          base "#000000"
        end

        value :css_vars, fn(:concat, [
                              "--primary: ", input.primary_color, "; ",
                              "--accent: ", accent_color, "; ",
                              "--text: ", text_color, "; ",
                              "--font-size: ", input.font_size, "px;"
                            ])
      end
    end

    it "handles realistic incremental configuration updates" do
      theme = theme_schema.from(
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

      # User changes primary color - should update accent_color and css_vars
      theme.update(primary_color: "#cc3366")

      expect(theme[:accent_color]).to eq("#cc3366-light")
      expect(theme[:css_vars]).to include("--primary: #cc3366")
      expect(theme[:css_vars]).to include("--accent: #cc3366-light")
    end
  end
end
