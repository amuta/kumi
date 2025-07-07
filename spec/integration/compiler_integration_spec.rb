# frozen_string_literal: true

RSpec.describe "Kumi Compiler Integration" do
  before(:all) do
    # Set up custom functions that our schema references
    # This shows how the function registry integrates with compiled schemas

    Kumi::MethodCallRegistry.register_with(:all?) do |conditions|
      conditions.all? { |condition| condition }
    end

    Kumi::MethodCallRegistry.register_with(:concat) do |*strings|
      strings.join
    end

    Kumi::MethodCallRegistry.register_with(:multiply) do |a, b|
      a * b
    end

    Kumi::MethodCallRegistry.register_with(:conditional) do |condition, true_value, false_value|
      condition ? true_value : false_value
    end

    Kumi::MethodCallRegistry.register_with(:error!) do |should_error|
      raise "ErrorInsideCustomFunction" if should_error

      "No Error"
    end

    Kumi::MethodCallRegistry.register_with(:create_offers) do |segment, tier, _balance|
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

    Kumi::MethodCallRegistry.register_with(:bonus_formula) do |years, is_valuable, engagement|
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
      # Notice how traits build on other traits, attributes reference multiple traits,
      # and functions consume both raw fields and computed attributes.

      Kumi::Parser::Dsl.schema do
        # === BASE TRAITS ===
        # These traits examine raw customer data to establish fundamental classifications
        # Traits use the syntax: trait name, lhs, operator, rhs

        trait :adult, key(:age), :>=, 18
        trait :senior, key(:age), :>=, 65
        trait :high_balance, key(:account_balance), :>=, 10_000
        trait :premium_account, key(:account_type), :==, "premium"
        trait :recent_activity, key(:last_purchase_days_ago), :<=, 30
        trait :frequent_buyer, key(:total_purchases), :>=, 50
        trait :long_term_customer, key(:years_customer), :>=, 5
        trait :has_referrals, key(:referral_count), :>, 0
        trait :low_support_usage, key(:support_tickets), :<=, 3

        # # === HELPER FUNCTIONS FOR COMPLEX LOGIC ===
        # # These functions encapsulate multi-condition logic, making traits more readable

        attribute :check_engagement, fn(:all?, [ref(:recent_activity), ref(:frequent_buyer)])
        attribute :check_value, fn(:all?, [ref(:high_balance), ref(:long_term_customer)])
        attribute :check_low_maintenance, fn(:all?, [ref(:low_support_usage), ref(:has_referrals)])

        # # === DERIVED TRAITS ===
        # # These traits reference helper functions, showing clean trait definitions
        # # that depend on complex multi-condition logic

        trait :engaged_customer, ref(:check_engagement), :==, literal(true)
        trait :valuable_customer, ref(:check_value), :==, literal(true)
        trait :low_maintenance, ref(:check_low_maintenance), :==, literal(true)

        # === COMPLEX ATTRIBUTES WITH CASCADING LOGIC ===
        # These attributes demonstrate cascade expressions that reference multiple traits
        # The compiler must handle the binding lookups correctly when the cascade evaluates

        attribute :customer_tier do
          on_trait :senior, literal("Senior VIP")
          on_traits :valuable_customer, :engaged_customer, literal("Gold")
          on_trait :premium_account, literal("Premium")
          on_trait :adult, literal("Standard")
          default literal("Basic")
        end

        attribute :marketing_segment do
          on_traits :valuable_customer, :low_maintenance, literal("Champion")
          on_trait :engaged_customer, literal("Loyal Customer")
          on_traits :high_balance, :recent_activity, literal("Big Spender")
          on_trait :frequent_buyer, literal("Frequent Buyer")
          default literal("Potential")
        end

        attribute :user_error, fn(:error!, key(:should_error))

        # === ATTRIBUTES THAT COMBINE MULTIPLE DATA SOURCES ===
        # These show how attributes can reference both raw fields and computed traits

        attribute :welcome_message, fn(:concat, [
                                         literal("Hello "),
                                         key(:name),
                                         literal(", you are a "),
                                         ref(:customer_tier),
                                         literal(" customer!")
                                       ])

        attribute :engagement_score, fn(:multiply,
                                        key(:total_purchases),
                                        fn(:conditional, ref(:engaged_customer), literal(1.5), literal(1.0)))

        # === FUNCTIONS THAT REFERENCE OTHER DEFINITIONS ===
        # Functions can consume both raw data and computed values, showing the
        # full power of cross-referencing in the compilation system

        attribute :generate_offers, fn(:create_offers,
                                       ref(:marketing_segment),
                                       ref(:customer_tier),
                                       key(:account_balance))

        attribute :calculate_loyalty_bonus, fn(:bonus_formula,
                                               key(:years_customer),
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
      it "correctly evaluates all traits with complex dependencies" do
        # Test that all the trait dependencies resolve correctly
        # This exercises the binding resolution logic extensively

        result = executable_schema.evaluate(customer_data)
        traits = result[:traits]
        attributes = result[:attributes]

        # Verify base traits computed from raw data
        expect(traits[:adult]).to be true
        expect(traits[:senior]).to be false # 45 < 65
        expect(traits[:high_balance]).to be true # 25,000 >= 10,000
        expect(traits[:premium_account]).to be true
        expect(traits[:recent_activity]).to be true # 15 <= 30
        expect(traits[:frequent_buyer]).to be true # 127 >= 50
        expect(traits[:long_term_customer]).to be true # 8 >= 5
        expect(traits[:has_referrals]).to be true # 3 > 0
        expect(traits[:low_support_usage]).to be true # 2 <= 3

        # Verify helper functions that combine multiple conditions
        expect(attributes[:check_engagement]).to be true # recent_activity AND frequent_buyer
        expect(attributes[:check_value]).to be true # high_balance AND long_term_customer
        expect(attributes[:check_low_maintenance]).to be true # low_support_usage AND has_referrals

        # Verify derived traits that reference helper functions
        # These test the binding resolution where traits depend on functions
        # that themselves reference other traits
        expect(traits[:engaged_customer]).to be true # check_engagement() == true
        expect(traits[:valuable_customer]).to be true # check_value() == true
        expect(traits[:low_maintenance]).to be true # check_low_maintenance() == true
      end

      it "correctly evaluates cascade attributes with trait references" do
        # Test that cascade expressions properly resolve trait bindings
        # This is a complex test of the CascadeExpression compilation logic

        result = executable_schema.evaluate(customer_data)
        attributes = result[:attributes]

        # Customer is valuable_customer AND engaged_customer, so should get "Gold"
        expect(attributes[:customer_tier]).to eq("Gold")

        # Customer is valuable_customer AND low_maintenance, so should get "Champion"
        expect(attributes[:marketing_segment]).to eq("Champion")
      end

      it "correctly evaluates attributes that combine multiple reference types" do
        # Test attributes that reference both fields and computed traits
        # This exercises the mixed binding resolution in complex expressions

        result = executable_schema.evaluate(customer_data)
        attributes = result[:attributes]

        # Test string concatenation with field and trait references
        expected_message = "Hello Alice Johnson, you are a Gold customer!"
        expect(attributes[:welcome_message]).to eq(expected_message)

        # Test mathematical computation with field and trait references
        # 127 purchases * 1.5 (because engaged_customer is true) = 190.5
        expect(attributes[:engagement_score]).to eq(190.5)
      end

      it "correctly evaluates functions that consume computed values" do
        # Test that functions can reference attributes and traits computed earlier
        # This demonstrates the full power of cross-referencing in the system

        result = executable_schema.evaluate(customer_data)
        attributes = result[:attributes]

        # Test helper functions that combine multiple trait conditions
        expect(attributes[:check_engagement]).to be true
        expect(attributes[:check_value]).to be true
        expect(attributes[:check_low_maintenance]).to be true

        # Test offer generation based on computed marketing segment and tier
        offers = attributes[:generate_offers]
        expect(offers).to include("Exclusive Preview")  # Champion segment
        expect(offers).to include("VIP Events")         # Champion segment
        expect(offers).to include("Concierge Service")  # Gold tier bonus

        # Test loyalty bonus calculation using years, computed trait, and computed attribute
        # Formula: (years * 10) * 2 (valuable customer) * (engagement_score / 100)
        # (8 * 10) * 2 * (190.5 / 100) = 80 * 2 * 1.905 = 304.8
        bonus = attributes[:calculate_loyalty_bonus]
        expect(bonus).to eq(304.8)
      end
    end

    describe "partial evaluation capabilities" do
      it "can evaluate only traits without computing attributes or functions" do
        # Test that we can efficiently compute just the traits when that's all we need
        # This is important for performance in scenarios where you only need partial results

        traits = executable_schema.evaluate(customer_data)[:traits]

        expect(traits).to have_key(:adult)
        expect(traits).to have_key(:engaged_customer)
        expect(traits).to have_key(:valuable_customer)
        expect(traits[:engaged_customer]).to be true

        # Verify we only got traits, not attributes or functions
        expect(traits).not_to have_key(:customer_tier)
        expect(traits).not_to have_key(:check_engagement)
        expect(traits).not_to have_key(:generate_offers)
      end

      it "can evaluate only attributes, with trait dependencies resolved" do
        pending("TODO: expose: [:attribute_names,...] -> we used functions as private attributes, right now everything is public")
        #  before, but now, for clarity we only have attributes

        attributes = executable_schema.evaluate_attributes(customer_data)

        expect(attributes[:customer_tier]).to eq("Gold")
        expect(attributes[:marketing_segment]).to eq("Champion")
        expect(attributes[:engagement_score]).to eq(190.5)

        expect(attributes).not_to have_key(:adult)
        expect(attributes).not_to have_key(:check_engagement)
        expect(attributes).not_to have_key(:generate_offers)
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
        expect(result1[:traits][:high_balance]).to be true
        expect(result2[:traits][:high_balance]).to be false

        # But both should execute without recompilation
        expect(result1[:attributes][:customer_tier]).to eq("Gold")
        expect(result2[:attributes][:customer_tier]).to eq("Premium") # Different tier for different data
      end
    end
  end
end
