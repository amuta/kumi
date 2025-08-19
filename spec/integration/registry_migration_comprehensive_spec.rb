# frozen_string_literal: true

require "spec_helper"

# Comprehensive tests for the RegistryV2 migration
# This spec validates that the 10-phase migration plan is working correctly
# and all passes are using RegistryV2 with metadata-first approach
RSpec.describe "RegistryV2 Migration Integration" do
  # Test Phase 2: Normalization - operators like `>` become `core.gt`
  describe "Function Name Normalization" do
    it "normalizes operators to qualified names" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            integer :age
          end

          trait :is_adult, input.age > 18
          trait :is_teenager, (input.age >= 13) & (input.age < 20)
          value :age_category do
            on is_adult, "adult"
            base "child"
          end
        end
      end

      test_data = { age: 25 }
      result = schema.from(test_data)

      expect(result[:is_adult]).to eq(true)
      expect(result[:is_teenager]).to eq(false)
      expect(result[:age_category]).to eq("adult")
    end

    it "normalizes function calls to qualified names" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            array :prices do
              float :value
            end
          end

          value :max_price, fn(:max, input.prices.value)
          value :total_price, fn(:sum, input.prices.value)
        end
      end

      test_data = { prices: [{ value: 49.5 }, { value: 100.0 }] }
      result = schema.from(test_data)

      expect(result[:max_price]).to eq(100.0)
      expect(result[:total_price]).to eq(149.5)
    end
  end

  # Test Phase 1 & 7: Cascade desugar patterns (proper cascade syntax)
  describe "Cascade Desugar Patterns" do
    it "handles simple cascade conditions" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            boolean :active
            integer :priority
          end

          trait :is_active, input.active == true
          trait :high_priority, input.priority > 5

          value :status do
            on is_active, "enabled"
            on high_priority, "urgent"
            base "disabled"
          end
        end
      end

      test_data = { active: true, priority: 3 }
      result = schema.from(test_data)
      expect(result[:status]).to eq("enabled")

      test_data = { active: false, priority: 8 }
      result = schema.from(test_data)
      expect(result[:status]).to eq("urgent")

      test_data = { active: false, priority: 3 }
      result = schema.from(test_data)
      expect(result[:status]).to eq("disabled")
    end

    it "handles complex trait conditions" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            boolean :active
            boolean :verified
            integer :score
          end

          trait :is_active, input.active == true
          trait :is_verified, input.verified == true
          trait :high_score, input.score > 50
          trait :qualified, is_active & is_verified & high_score

          value :access_level do
            on qualified, "full"
            base "limited"
          end
        end
      end

      # All conditions true
      test_data = { active: true, verified: true, score: 75 }
      result = schema.from(test_data)
      expect(result[:access_level]).to eq("full")

      # One condition false
      test_data = { active: true, verified: false, score: 75 }
      result = schema.from(test_data)
      expect(result[:access_level]).to eq("limited")
    end
  end

  # Test Phase 4 & 6: Broadcasting with RegistryV2 function classes
  describe "Array Broadcasting with RegistryV2" do
    it "detects vectorized operations correctly" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            array :items do
              float :price
              integer :quantity
            end
          end

          value :subtotals, input.items.price * input.items.quantity
          value :total, fn(:sum, subtotals)
        end
      end

      test_data = {
        items: [
          { price: 10.0, quantity: 2 },
          { price: 15.0, quantity: 3 }
        ]
      }

      result = schema.from(test_data)
      expect(result[:subtotals]).to eq([20.0, 45.0])
      expect(result[:total]).to eq(65.0)
    end

    it "handles reduction operations with proper scope resolution" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            array :players do
              string :name
              array :scores do
                integer :value
              end
            end
          end

          trait :high_scorer, fn(:any?, input.players.scores.value > 100)
          value :player_max_scores, fn(:max, input.players.scores.value)
        end
      end

      test_data = {
        players: [
          { name: "Alice", scores: [{ value: 85 }, { value: 120 }] },
          { name: "Bob", scores: [{ value: 95 }, { value: 110 }] }
        ]
      }

      result = schema.from(test_data)
      expect(result[:high_scorer]).to eq(true)
      expect(result[:player_max_scores]).to eq([120, 110])
    end
  end

  # Test Phase 5: Type validation with metadata
  describe "Type Checking with RegistryV2" do
    it "validates function signatures from RegistryV2" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            array :numbers do
              integer :value
            end
          end

          value :total, fn(:sum, input.numbers.value)
          value :maximum, fn(:max, input.numbers.value)
        end
      end

      test_data = { numbers: [{ value: 10 }, { value: 25 }, { value: 5 }] }
      result = schema.from(test_data)
      expect(result[:total]).to eq(40)
      expect(result[:maximum]).to eq(25)
    end

    it "reports errors for invalid function calls" do
      expect do
        Module.new do
          extend Kumi::Schema

          schema do
            input do
              string :name
            end

            value :invalid, fn(:nonexistent_function, input.name)
          end
        end
      end.to raise_error(/unknown function/)
    end
  end

  # Test Phase 8: Cross-scope references with qualified names
  describe "Cross-Scope References" do
    it "handles references between declarations with qualified names" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            array :items do
              float :price
              integer :quantity
            end
            float :tax_rate
          end

          value :subtotals, input.items.price * input.items.quantity
          value :total_before_tax, fn(:sum, subtotals)
          value :total_with_tax, total_before_tax * input.tax_rate
        end
      end

      test_data = {
        items: [
          { price: 100.0, quantity: 2 },
          { price: 50.0, quantity: 1 }
        ],
        tax_rate: 1.1
      }

      result = schema.from(test_data)
      expect(result[:total_before_tax]).to eq(250.0)
      expect(result[:total_with_tax]).to eq(275.0)
    end
  end

  # Test that the metadata pipeline works end-to-end
  describe "Metadata Pipeline Integration" do
    it "preserves metadata through all passes" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            array :numbers do
              integer :value
            end
          end

          trait :has_large_number, fn(:any?, input.numbers.value > 100)
          value :classification do
            on has_large_number, "contains_large"
            base "all_small"
          end
          value :max_number, fn(:max, input.numbers.value)
        end
      end

      test_data = {
        numbers: [
          { value: 50 },
          { value: 150 },
          { value: 75 }
        ]
      }

      result = schema.from(test_data)
      expect(result[:has_large_number]).to eq(true)
      expect(result[:classification]).to eq("contains_large")
      expect(result[:max_number]).to eq(150)
    end
  end

  # Test complex nested scenarios
  describe "Complex Nested Scenarios" do
    it "handles deeply nested structures with multiple function types" do
      schema = Module.new do
        extend Kumi::Schema

        schema do
          input do
            array :departments do
              string :name
              array :employees do
                string :name
                integer :salary
                array :projects do
                  string :title
                  integer :hours
                end
              end
            end
          end

          # Test vectorized operations at different levels
          value :employee_project_hours, input.departments.employees.projects.hours
          value :employee_total_hours, fn(:sum, employee_project_hours)

          # Test reduction with scope preservation
          trait :has_high_earner, fn(:any?, input.departments.employees.salary > 80_000)

          # Test cascade with cross-scope references
          value :department_status do
            on has_high_earner, "premium"
            base "standard"
          end
        end
      end

      test_data = {
        departments: [
          {
            name: "Engineering",
            employees: [
              {
                name: "Alice",
                salary: 90_000,
                projects: [
                  { title: "Project A", hours: 40 },
                  { title: "Project B", hours: 20 }
                ]
              }
            ]
          },
          {
            name: "Marketing",
            employees: [
              {
                name: "Bob",
                salary: 60_000,
                projects: [
                  { title: "Campaign X", hours: 30 }
                ]
              }
            ]
          }
        ]
      }

      result = schema.from(test_data)
      expect(result[:has_high_earner]).to eq(true)
      expect(result[:department_status]).to eq("premium")

      # Verify nested array access works - expect flattened structure
      expect(result[:employee_total_hours]).to eq([60, 30])
    end
  end
end
