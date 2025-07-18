# frozen_string_literal: true

RSpec.describe "Kumi Compiler Integration" do
  before(:all) do
    Kumi::FunctionRegistry.reset!

    Kumi::FunctionRegistry.register(:error!) do |should_error|
      raise "ErrorInsideCustomFunction" if should_error

      "No Error"
    end

    Kumi::FunctionRegistry.register(:create_offers) do |segment, tier, _balance|
      base_offers = case segment
                    when "Champion" then ["Exclusive Preview", "VIP Events", "Personal Advisor"]
                    when "Loyal Customer" then ["Loyalty Rewards", "Member Discounts"]
                    when "Big Spender" then ["Cashback Offers", "Premium Services"]
                    when "Frequent Buyer" then ["Volume Discounts", "Free Shipping"]
                    else ["Welcome Bonus"]
                    end

      # Add tier-specific bonuses
      base_offers << "Concierge Service" if tier.include?("VIP") || tier == "Gold"

      base_offers
    end

    Kumi::FunctionRegistry.register(:bonus_formula) do |years, is_valuable, engagement|
      base_bonus = years * 10
      base_bonus *= 2 if is_valuable
      (base_bonus * (engagement / 100.0)).round(2)
    end
  end

  describe "Customer Segmentation System" do
    let(:customer_data) do
      {
        name: "Alice Johnson",
        age: 45,
        account_balance: 25_000,
        years_customer: 8,
        last_purchase_days_ago: 15,
        total_purchases: 127,
        account_type: "premium",
        referral_count: 3,
        support_tickets: 2,
        should_error: false # Used to test error handling in functions
      }
    end

    let(:schema) do
      # This schema demonstrates complex interdependencies between different types of definitions.
      # Notice how predicates build on other predicates, attributes reference multiple predicates,
      # and functions consume both raw fields and computed attributes.

      Kumi::Parser::Dsl.build_sytax_tree do
        input do
          key :name, type: :string # Kumi::Types::STRING
          key :age, type: :integer # Kumi::Types::INT
          key :account_balance, type: :float # Kumi::Types::FLOAT
          key :years_customer, type: :integer # Kumi::Types::INT
          key :last_purchase_days_ago, type: :integer # Kumi::Types::INT
          key :total_purchases, type: :integer # Kumi::Types::INT
          key :account_type, type: :string # Kumi::Types::STRING
          key :referral_count, type: :integer # Kumi::Types::INT
          key :support_tickets, type: :integer # Kumi::Types::INT
          key :should_error, type: :boolean # Kumi::Types::BOOL
        end

        # === BASE predicateS ===
        # These predicates examine raw customer data to establish fundamental classifications
        # predicates use the syntax: predicate name, lhs, operator, rhs

        predicate :adult, input.age, :>=, 18
        predicate :senior, input.age, :>=, 65
        predicate :high_balance, input.account_balance, :>=, 10_000
        predicate :premium_account, input.account_type, :==, "premium"
        predicate :recent_activity, input.last_purchase_days_ago, :<=, 30
        predicate :frequent_buyer, input.total_purchases, :>=, 50
        predicate :long_term_customer, input.years_customer, :>=, 5
        predicate :has_referrals, input.referral_count, :>, 0
        predicate :low_support_usage, input.support_tickets, :<=, 3

        # # === HELPER FUNCTIONS FOR COMPLEX LOGIC ===
        # # These functions encapsulate multi-condition logic, making predicates more readable

        value :check_engagement, fn(:all?, [ref(:recent_activity), ref(:frequent_buyer)])
        value :check_value, fn(:all?, [ref(:high_balance), ref(:long_term_customer)])
        value :check_low_maintenance, fn(:all?, [ref(:low_support_usage), ref(:has_referrals)])

        # # === DERIVED predicateS ===
        # # These predicates reference helper functions, showing clean predicate definitions
        # # that depend on complex multi-condition logic

        predicate :engaged_customer, ref(:check_engagement), :==, true
        predicate :valuable_customer, ref(:check_value), :==, true
        predicate :low_maintenance, ref(:check_low_maintenance), :==, true

        # === COMPLEX ATTRIBUTES WITH CASCADING LOGIC ===
        # These attributes demonstrate cascade expressions that reference multiple predicates
        # The compiler must handle the binding lookups correctly when the cascade evaluates

        value :customer_tier do
          on :senior, "Senior VIP"
          on :valuable_customer, :engaged_customer, "Gold"
          on :premium_account, "Premium"
          on :adult, "Standard"
          base "Basic"
        end

        value :marketing_segment do
          on :valuable_customer, :low_maintenance, "Champion"
          on :engaged_customer, "Loyal Customer"
          on :high_balance, :recent_activity, "Big Spender"
          on :frequent_buyer, "Frequent Buyer"
          base "Potential"
        end

        value :user_error, fn(:error!, input.should_error)

        # === ATTRIBUTES THAT COMBINE MULTIPLE DATA SOURCES ===
        # These show how attributes can reference both raw fields and computed predicates

        value :welcome_message, fn(:concat, [
                                     "Hello ",
                                     input.name,
                                     ", you are a ",
                                     ref(:customer_tier),
                                     " customer!"
                                   ])

        value :engagement_score, fn(:multiply,
                                    input.total_purchases,
                                    fn(:conditional, ref(:engaged_customer), 1.5, 1.0))

        # === FUNCTIONS THAT REFERENCE OTHER DEFINITIONS ===
        # Functions can consume both raw data and computed values, showing the
        # full power of cross-referencing in the compilation system

        value :generate_offers, fn(:create_offers,
                                   ref(:marketing_segment),
                                   ref(:customer_tier),
                                   input.account_balance)

        value :calculate_loyalty_bonus, fn(:bonus_formula,
                                           input.years_customer,
                                           ref(:valuable_customer),
                                           ref(:engagement_score))
      end
    end

    let(:executable_schema) do
      # This demonstrates the full compilation pipeline:
      # 1. Parse the DSL into an AST
      # 2. Link and validate all cross-references
      # 3. Compile into executable lambda functions

      parsed_schema = schema # Already parsed by the DSL
      analyzer_result = Kumi::Analyzer.analyze!(parsed_schema)
      Kumi::Compiler.compile(parsed_schema, analyzer: analyzer_result)
    end

    describe "full schema evaluation" do
      it "correctly evaluates all predicates with complex dependencies" do
        # Test that all the predicate dependencies resolve correctly
        # This exercises the binding resolution logic extensively

        result = executable_schema.evaluate(customer_data)
        result[:predicates]
        result[:attributes]

        expect(result[:adult]).to be true
        expect(result[:senior]).to be false # 45 < 65
        expect(result[:high_balance]).to be true # 25,000 >= 10,000
        expect(result[:premium_account]).to be true
        expect(result[:recent_activity]).to be true # 15 <= 30
        expect(result[:frequent_buyer]).to be true # 127 >= 50
        expect(result[:long_term_customer]).to be true # 8 >= 5
        expect(result[:has_referrals]).to be true # 3 > 0
        expect(result[:low_support_usage]).to be true # 2 <= 3

        # Verify helper values that combine multiple conditions
        expect(result[:check_engagement]).to be true # recent_activity AND frequent_buyer
        expect(result[:check_value]).to be true # high_balance AND long_term_customer
        expect(result[:check_low_maintenance]).to be true # low_support_usage AND has_referrals

        # Verify derived values that reference helper functions
        # These test the binding resolution logic for predicates
        # that themselves reference other predicates
        expect(result[:engaged_customer]).to be true # check_engagement() == true
        expect(result[:valuable_customer]).to be true # check_value() == true
        expect(result[:low_maintenance]).to be true # check_low_maintenance() == true
      end

      it "correctly evaluates cascade attributes with predicate references" do
        # Test that cascade expressions properly resolve predicate bindings
        # This is a complex test of the CascadeExpression compilation logic

        result = executable_schema.evaluate(customer_data)

        # Customer is valuable_customer AND engaged_customer, so should get "Gold"
        expect(result[:customer_tier]).to eq("Gold")

        # Customer is valuable_customer AND low_maintenance, so should get "Champion"
        expect(result[:marketing_segment]).to eq("Champion")
      end

      it "correctly evaluates attributes that combine multiple reference types" do
        # Test attributes that reference both fields and computed predicates
        # This exercises the mixed binding resolution in complex expressions

        result = executable_schema.evaluate(customer_data)
        result[:attributes]

        # Test string concatenation with field and predicate references
        expected_message = "Hello Alice Johnson, you are a Gold customer!"
        expect(result[:welcome_message]).to eq(expected_message)

        # Test mathematical computation with field and predicate references
        # 127 purchases * 1.5 (because engaged_customer is true) = 190.5
        expect(result[:engagement_score]).to eq(190.5)
      end

      it "correctly evaluates functions that consume computed values" do
        # Test that functions can reference attributes and predicates computed earlier
        # This demonstrates the full power of cross-referencing in the system

        result = executable_schema.evaluate(customer_data)

        # Test helper functions that combine multiple predicate conditions
        expect(result[:check_engagement]).to be true
        expect(result[:check_value]).to be true
        expect(result[:check_low_maintenance]).to be true

        # Test offer generation based on computed marketing segment and tier
        offers = result[:generate_offers]
        expect(offers).to include("Exclusive Preview")  # Champion segment
        expect(offers).to include("VIP Events")         # Champion segment
        expect(offers).to include("Concierge Service")  # Gold tier bonus

        # Test loyalty bonus calculation using years, computed predicate, and computed attribute
        # Formula: (years * 10) * 2 (valuable customer) * (engagement_score / 100)
        # (8 * 10) * 2 * (190.5 / 100) = 80 * 2 * 1.905 = 304.8
        bonus = result[:calculate_loyalty_bonus]
        expect(bonus).to eq(304.8)
      end
    end

    describe "partial evaluation capabilities" do
      it "can evaluate only predicates without computing attributes or functions" do
        # Test that we can efficiently compute just the predicates when that's all we need
        # This is important for performance in scenarios where you only need partial results

        result = executable_schema.evaluate(customer_data)

        expect(result).to have_key(:adult)
        expect(result).to have_key(:engaged_customer)
        expect(result).to have_key(:valuable_customer)
        expect(result[:engaged_customer]).to be true
      end

      it "can evaluate individual bindings on demand" do
        # Test that we can compute single values efficiently
        # This exercises the binding lookup logic in isolation

        tier = executable_schema.evaluate_binding(:customer_tier, customer_data)
        expect(tier).to eq("Gold")

        offers = executable_schema.evaluate_binding(:generate_offers, customer_data)
        expect(offers).to include("Exclusive Preview")

        is_engaged = executable_schema.evaluate_binding(:engaged_customer, customer_data)
        expect(is_engaged).to be true

        # Test that helper functions work when evaluated individually
        engagement_check = executable_schema.evaluate_binding(:check_engagement, customer_data)
        expect(engagement_check).to be true
      end
    end

    describe "edge cases and error handling" do
      it "handles missing fields gracefully with clear error messages" do
        # Test that field access errors are reported clearly
        incomplete_data = customer_data.except(:age)

        expect do
          executable_schema.evaluate(incomplete_data)
        end.to raise_error(Kumi::Errors::RuntimeError, /Key 'age' not found/)
      end

      it "handles function errors with context information" do
        data_with_error_field = customer_data.merge(should_error: true)

        # Temporarily break a function to test error handling
        expect do
          executable_schema.evaluate(data_with_error_field)
        end.to raise_error(Kumi::Errors::RuntimeError, /Error calling fn\(:error!\)/)
      end

      it "do not work with objects that do not implement key? method" do
        # Test that the compiler's flexible context handling works correctly

        # Test with an OpenStruct instead of a Hash
        struct_data = Struct.new(*customer_data.keys).new(*customer_data.values)

        expect do
          executable_schema.evaluate(struct_data)
        end.to raise_error(Kumi::Errors::RuntimeError, /Data context should be Hash-like/)
      end
    end

    describe "performance characteristics" do
      it "compiles once and executes efficiently multiple times" do
        # Test that compilation is separate from execution
        # This demonstrates that the expensive work happens once during compilation

        # First execution
        result1 = executable_schema.evaluate(customer_data)

        # Second execution with different data should reuse the compiled functions
        different_customer = customer_data.merge(age: 25, account_balance: 5_000)
        result2 = executable_schema.evaluate(different_customer)

        # Results should be different because data is different
        expect(result1[:high_balance]).to be true
        expect(result2[:high_balance]).to be false

        # But both should execute without recompilation
        expect(result1[:customer_tier]).to eq("Gold")
        expect(result2[:customer_tier]).to eq("Premium") # Different tier for different data
      end
    end
  end
end
