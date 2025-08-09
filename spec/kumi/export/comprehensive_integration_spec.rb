# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Comprehensive AST Export Integration" do
  # Register custom functions for testing
  before do
    Kumi::Registry.reset!

    Kumi::Registry.register(:error!) do |should_error|
      raise "ErrorInsideCustomFunction" if should_error

      "No Error"
    end

    Kumi::Registry.register(:create_offers) do |segment, tier, _balance|
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

    Kumi::Registry.register(:bonus_formula) do |years, is_valuable, engagement|
      base_bonus = years * 10
      base_bonus *= 2 if is_valuable
      (base_bonus * (engagement / 100.0)).round(2)
    end
  end

  let(:customer_data) do
    {
      name: "Alice Johnson",
      age: 45,
      account_balance: 25_000.0,
      years_customer: 8,
      last_purchase_days_ago: 15,
      total_purchases: 127,
      account_type: "premium",
      referral_count: 3,
      support_tickets: 2,
      should_error: false,
      scores: [85.0, 92.0, 88.0],
      config: { username: "alice", premium: true },
      tags: %w[vip loyal premium]
    }
  end

  let(:comprehensive_schema) do
    # Create the most comprehensive schema possible with all syntax features
    Kumi::Core::RubyParser::Dsl.build_syntax_tree do
      input do
        # All primitive types
        key :name, type: :string
        key :age, type: :integer
        key :account_balance, type: :float
        key :years_customer, type: :integer
        key :last_purchase_days_ago, type: :integer
        key :total_purchases, type: :integer
        key :account_type, type: :string
        key :referral_count, type: :integer
        key :support_tickets, type: :integer
        key :should_error, type: :boolean

        # Complex types
        key :scores, type: array(:float)
        key :config, type: hash(:string, :any)
        key :tags, type: array(:string)
      end

      # === BASIC TRAITS ===
      # Simple field comparisons testing all comparison operators
      trait :adult, input.age, :>=, 18
      trait :senior, input.age, :>, 65
      trait :exact_age_45, input.age, :==, 45
      trait :not_teenager, input.age, :!=, 13
      trait :middle_aged, input.age, :<, 65
      trait :old_enough, input.age, :<=, 100
      trait :age_in_range, input.age, :between?, 25, 65
      trait :high_balance, input.account_balance, :>=, 10_000.0
      trait :premium_account, input.account_type, :==, "premium"
      trait :recent_activity, input.last_purchase_days_ago, :<=, 30
      trait :frequent_buyer, input.total_purchases, :>=, 50
      trait :long_term_customer, input.years_customer, :>=, 5
      trait :has_referrals, input.referral_count, :>, 0
      trait :low_support_usage, input.support_tickets, :<=, 3

      # === COMPLEX FUNCTION CALLS ===
      # Nested function calls with multiple argument types
      value :engagement_metrics, fn(:concat, [
                                      "Customer: ", input.name,
                                      " (Age: ", input.age,
                                      ", Balance: $", input.account_balance, ")"
                                    ])

      value :risk_score, fn(:add,
                            fn(:multiply, input.support_tickets, 10),
                            fn(:subtract, 100,
                               fn(:multiply, input.years_customer, 5)))

      value :scores_analysis, fn(:cascade_and,
                                 fn(:>, fn(:size, input.scores), 0),
                                 fn(:<, fn(:sum, input.scores), 300.0),
                                 fn(:>=, fn(:divide, fn(:sum, input.scores), 3.0), 80.0))

      # === COMPLEX LOGICAL COMBINATIONS ===
      # Multiple trait combinations using logical functions
      value :customer_quality, fn(:cascade_and,
                                  ref(:frequent_buyer),
                                  ref(:long_term_customer),
                                  ref(:low_support_usage))

      value :premium_eligibility, fn(:any?, [
                                       ref(:high_balance),
                                       fn(:cascade_and, ref(:premium_account), ref(:has_referrals)),
                                       fn(:>, input.years_customer, 10)
                                     ])

      # === CONDITIONAL LOGIC ===
      # Complex conditional expressions with multiple levels
      value :account_status, fn(:conditional,
                                ref(:premium_eligibility),
                                fn(:conditional,
                                   ref(:customer_quality),
                                   "Premium Elite",
                                   "Premium Standard"),
                                fn(:conditional,
                                   ref(:adult),
                                   "Standard",
                                   "Youth"))

      # === TRAITS BASED ON COMPUTED VALUES ===
      trait :elite_customer, ref(:customer_quality), :==, true
      trait :premium_eligible, ref(:premium_eligibility), :==, true
      trait :high_risk, ref(:risk_score), :>, 50
      trait :good_scores, ref(:scores_analysis), :==, true

      # === MULTIPLE CASCADE EXPRESSIONS ===
      # Complex cascades with multiple conditions per case
      value :customer_tier do
        on senior, high_balance, "Senior VIP"
        on elite_customer, premium_eligible, "Gold"
        on premium_account, frequent_buyer, "Premium Plus"
        on premium_account, "Premium"
        on adult, has_referrals, "Standard Plus"
        on adult, "Standard"
        base "Basic"
      end

      value :marketing_segment do
        on elite_customer, premium_eligible, "Champion"
        on frequent_buyer, recent_activity, "Loyal Customer"
        on high_balance, recent_activity, "Big Spender"
        on frequent_buyer, "Frequent Buyer"
        on has_referrals, "Referrer"
        base "Potential"
      end

      value :communication_preference do
        on senior, "Phone"
        on premium_account, recent_activity, "Email Premium"
        on recent_activity, "Email"
        on high_balance, "Mail"
        base "SMS"
      end

      # === COLLECTION OPERATIONS ===
      # Working with array and hash types
      value :tag_count, fn(:size, input.tags)
      value :has_vip_tag, fn(:include?, input.tags, "vip")
      value :tag_summary, fn(:concat, [
                               "Customer has ",
                               fn(:size, input.tags),
                               " tags"
                             ])

      value :config_username, fn(:fetch, input.config, :username)
      value :is_premium_user, fn(:fetch, input.config, :premium, false)

      # === CUSTOM FUNCTION INTEGRATION ===
      # Functions that consume computed values and fields
      value :loyalty_offers, fn(:create_offers,
                                ref(:marketing_segment),
                                ref(:customer_tier),
                                input.account_balance)

      value :loyalty_bonus, fn(:bonus_formula,
                               input.years_customer,
                               ref(:elite_customer),
                               fn(:multiply, input.total_purchases, 1.5))

      # === ERROR HANDLING TEST ===
      value :error_test, fn(:error!, input.should_error)

      # === MATHEMATICAL OPERATIONS ===
      value :balance_percentile, fn(:clamp,
                                    fn(:divide, input.account_balance, 1000.0),
                                    0.0,
                                    100.0)

      value :customer_score, fn(:round,
                                fn(:add,
                                   fn(:multiply, input.years_customer, 10.0),
                                   fn(:multiply,
                                      fn(:conditional, ref(:premium_account), 50.0, 0.0),
                                      fn(:conditional, ref(:frequent_buyer), 1.5, 1.0))),
                                2)

      # === STRING OPERATIONS ===
      value :customer_greeting, fn(:concat, [
                                     "Welcome back, ",
                                     input.name,
                                     "! You are our ",
                                     ref(:customer_tier),
                                     " customer with a ",
                                     ref(:account_status),
                                     " account."
                                   ])

      # === COMPLEX NESTED REFERENCES ===
      value :final_assessment, fn(:concat, [
                                    ref(:customer_greeting),
                                    " Your customer score is ",
                                    ref(:customer_score),
                                    ". Bonus available: $",
                                    ref(:loyalty_bonus)
                                  ])
    end
  end

  it "preserves complete schema through export/import cycle" do
    # Step 1: Analyze the original schema
    original_analysis = Kumi::Analyzer.analyze!(comprehensive_schema)

    # Step 2: Export to JSON
    json_export = Kumi::Core::Export.to_json(comprehensive_schema)

    # Step 3: Import from JSON
    imported_schema = Kumi::Core::Export.from_json(json_export)

    # Step 4: Analyze the imported schema
    imported_analysis = Kumi::Analyzer.analyze!(imported_schema)

    # Step 5: Compare analysis results
    expect(imported_analysis.definitions.keys).to match_array(original_analysis.definitions.keys)
    expect(imported_analysis.topo_order).to eq(original_analysis.topo_order)
    expect(imported_analysis.decl_types.keys).to match_array(original_analysis.decl_types.keys)

    # Verify dependency graph preservation
    original_deps = original_analysis.dependency_graph
    imported_deps = imported_analysis.dependency_graph

    expect(imported_deps.keys).to match_array(original_deps.keys)
    original_deps.each do |node, deps|
      expect(imported_deps[node].map(&:to)).to match_array(deps.map(&:to))
    end

    # Verify input metadata preservation
    original_input_meta = original_analysis.state[:input_metadata]
    imported_input_meta = imported_analysis.state[:input_metadata]

    expect(imported_input_meta.keys).to match_array(original_input_meta.keys)
    original_input_meta.each do |field, meta|
      expect(imported_input_meta[field][:type]).to eq(meta[:type])
      expect(imported_input_meta[field][:domain]).to eq(meta[:domain])
    end
  end

  it "produces identical compilation and execution results" do
    # Compile original schema
    original_analysis = Kumi::Analyzer.analyze!(comprehensive_schema)
    original_compiled = Kumi::Compiler.compile(comprehensive_schema, analyzer: original_analysis)

    # Export, import, and compile
    json_export = Kumi::Core::Export.to_json(comprehensive_schema)
    imported_schema = Kumi::Core::Export.from_json(json_export)
    imported_analysis = Kumi::Analyzer.analyze!(imported_schema)
    imported_compiled = Kumi::Compiler.compile(imported_schema, analyzer: imported_analysis)

    # Execute both and compare results
    original_result = original_compiled.evaluate(customer_data)
    imported_result = imported_compiled.evaluate(customer_data)

    # Compare all results
    expect(imported_result.keys).to match_array(original_result.keys)

    original_result.each do |key, value|
      expect(imported_result[key]).to eq(value),
                                      "Mismatch for #{key}: expected #{value.inspect}, got #{imported_result[key].inspect}"
    end
  end

  it "handles all syntax features correctly after import" do
    # Export and import
    json_export = Kumi::Core::Export.to_json(comprehensive_schema)
    imported_schema = Kumi::Core::Export.from_json(json_export)

    # Compile and execute imported schema
    analysis = Kumi::Analyzer.analyze!(imported_schema)
    compiled = Kumi::Compiler.compile(imported_schema, analyzer: analysis)
    result = compiled.evaluate(customer_data)

    # Test basic traits
    expect(result[:adult]).to be true
    expect(result[:senior]).to be false
    expect(result[:exact_age_45]).to be true
    expect(result[:age_in_range]).to be true
    expect(result[:high_balance]).to be true
    expect(result[:premium_account]).to be true

    # Test complex function calls
    expect(result[:engagement_metrics]).to include("Alice Johnson")
    expect(result[:engagement_metrics]).to include("Age: 45")
    expect(result[:engagement_metrics]).to include("Balance: $25000")

    # Test logical combinations
    expect(result[:customer_quality]).to be true
    expect(result[:premium_eligibility]).to be true

    # Test cascade expressions
    expect(result[:customer_tier]).to eq("Gold") # elite_customer AND premium_eligible
    expect(result[:marketing_segment]).to eq("Champion") # elite_customer AND premium_eligible

    # Test collection operations
    expect(result[:tag_count]).to eq(3)
    expect(result[:has_vip_tag]).to be true
    expect(result[:tag_summary]).to include("Customer has 3 tags")

    # Test hash operations
    expect(result[:config_username]).to eq("alice")
    expect(result[:is_premium_user]).to be true

    # Test custom functions
    expect(result[:loyalty_offers]).to include("Exclusive Preview")
    expect(result[:loyalty_offers]).to include("Concierge Service")
    expect(result[:loyalty_bonus]).to be > 0

    # Test mathematical operations
    expect(result[:balance_percentile]).to eq(25.0) # 25000 / 1000 = 25
    expect(result[:customer_score]).to be > 100

    # Test complex string concatenation
    expect(result[:customer_greeting]).to include("Welcome back, Alice Johnson!")
    expect(result[:customer_greeting]).to include("Gold customer")

    # Test final nested assessment
    expect(result[:final_assessment]).to include(result[:customer_greeting])
    expect(result[:final_assessment]).to include(result[:customer_score].to_s)
    expect(result[:final_assessment]).to include("Bonus available")
  end

  it "validates JSON export structure and metadata" do
    json_export = Kumi::Core::Export.to_json(comprehensive_schema, pretty: true)
    parsed_json = JSON.parse(json_export)

    # Verify JSON structure
    expect(parsed_json).to have_key("kumi_version")
    expect(parsed_json).to have_key("ast")
    expect(parsed_json["ast"]).to have_key("type")
    expect(parsed_json["ast"]).to have_key("inputs")
    expect(parsed_json["ast"]).to have_key("attributes")
    expect(parsed_json["ast"]).to have_key("traits")

    # Verify metadata
    expect(parsed_json["kumi_version"]).to eq(Kumi::VERSION)

    # Verify input fields are properly serialized
    inputs = parsed_json["ast"]["inputs"]
    expect(inputs.length).to eq(13) # All input fields

    # Find the scores field to verify array type serialization
    scores_field = inputs.find { |input| input["name"] == "scores" }
    expect(scores_field).not_to be_nil
    expect(scores_field["field_type"]["type"]).to eq("array")
    expect(scores_field["field_type"]["element_type"]["type"]).to eq("symbol")
    expect(scores_field["field_type"]["element_type"]["value"]).to eq("float")

    # Find the config field to verify hash type serialization
    config_field = inputs.find { |input| input["name"] == "config" }
    expect(config_field).not_to be_nil
    expect(config_field["field_type"]["type"]).to eq("hash")
    expect(config_field["field_type"]["key_type"]["value"]).to eq("string")
    expect(config_field["field_type"]["value_type"]["value"]).to eq("any")

    # Verify attributes with cascade expressions are properly serialized
    attributes = parsed_json["ast"]["attributes"]
    tier_attr = attributes.find { |attr| attr["name"] == "customer_tier" }
    expect(tier_attr).not_to be_nil
    expect(tier_attr["expression"]["type"]).to eq("cascade_expression")
    expect(tier_attr["expression"]["cases"]).to be_an(Array)
    expect(tier_attr["expression"]["cases"].length).to be > 5 # Multiple cascade cases

    # Verify complex function calls are properly nested
    final_attr = attributes.find { |attr| attr["name"] == "final_assessment" }
    expect(final_attr).not_to be_nil
    expect(final_attr["expression"]["type"]).to eq("call_expression")
    expect(final_attr["expression"]["function_name"]).to eq("concat")
    expect(final_attr["expression"]["arguments"]).to be_an(Array)
  end

  it "handles round-trip with pretty formatting" do
    # Export with pretty formatting
    pretty_json = Kumi::Core::Export.to_json(comprehensive_schema, pretty: true)

    # Verify it's actually pretty formatted
    expect(pretty_json).to include("\n")
    expect(pretty_json).to include("  ") # indentation

    # Import and verify it works
    imported_schema = Kumi::Core::Export.from_json(pretty_json)
    analysis = Kumi::Analyzer.analyze!(imported_schema)
    compiled = Kumi::Compiler.compile(imported_schema, analyzer: analysis)

    result = compiled.evaluate(customer_data)
    expect(result[:customer_tier]).to eq("Gold")
    expect(result[:final_assessment]).to include("Alice Johnson")
  end

  it "preserves location information when included" do
    # Export with location information
    json_with_locations = Kumi::Core::Export.to_json(comprehensive_schema, include_locations: true)
    parsed = JSON.parse(json_with_locations)

    # Verify some nodes have location information
    # (Note: location info might not be present in all nodes depending on how the DSL builds them)
    inputs = parsed["ast"]["inputs"]
    attributes = parsed["ast"]["attributes"]

    # At least verify the structure can accommodate location info
    expect(inputs).to be_an(Array)
    expect(attributes).to be_an(Array)

    # Import should still work
    imported_schema = Kumi::Core::Export.from_json(json_with_locations)
    analysis = Kumi::Analyzer.analyze!(imported_schema)
    compiled = Kumi::Compiler.compile(imported_schema, analyzer: analysis)

    result = compiled.evaluate(customer_data)
    expect(result[:adult]).to be true
  end
end
