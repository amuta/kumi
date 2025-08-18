# frozen_string_literal: true

RSpec.describe "Kumi Compiler Integration" do
  before(:all) do
    Kumi::Registry.define_eachwise("error!") do |f|
      f.summary "Test error function"
      f.dtypes({ result: "string" })
      f.kernel do |should_error|
        raise "ErrorInsideCustomFunction" if should_error
        "No Error"
      end
    end

    Kumi::Registry.define_eachwise("create_offers") do |f|
      f.summary "Creates customer offers based on segment and tier"
      f.signature "(),(),()->()", "(s),(s),(i)->(a)"
      f.dtypes({ "result" => "any" })  # Returns array
      f.kernel do |segment, tier, _balance|
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
    end

    Kumi::Registry.define_eachwise("bonus_formula") do |f|
      f.summary "Calculates bonus based on years, value status and engagement"
      f.signature "(),(),()->()", "(i),(b),(f)->(f)"
      f.dtypes({ result: "float" })
      f.kernel do |years, is_valuable, engagement|
        base_bonus = years * 10
        base_bonus *= 2 if is_valuable
        (base_bonus * (engagement / 100.0)).round(2)
      end
    end
  end
  
  after(:all) do
    ["error!", "create_offers", "bonus_formula"].each do |func_name|
      Kumi::Registry.custom_functions.delete(func_name)
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

  it "compiles and executes a comprehensive schema using all registered functions" do
    schema = Kumi::Core::RubyParser::Dsl.build_syntax_tree do
      input do
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
        key :scores, type: array(:float)
        key :config, type: hash(:string, :any)
        key :tags, type: array(:string)
      end

      # Basic traits
      trait :adult, input.age, :>=, 18
      trait :high_balance, input.account_balance, :>=, 10_000.0
      trait :premium_account, input.account_type, :==, "premium"
      trait :frequent_buyer, input.total_purchases, :>=, 50

      # Values using custom functions
      value :loyalty_offers, fn(:create_offers, "Champion", "Gold", input.account_balance)
      value :loyalty_bonus, fn(:bonus_formula, input.years_customer, ref(:high_balance), 85.0)
      value :error_test, fn(:error!, input.should_error)
    end

    # Analyze and compile
    analysis = Kumi::Analyzer.analyze!(schema)
    compiled = Kumi::Compiler.compile(schema, analyzer: analysis)

    # Execute
    result = compiled.evaluate(customer_data)

    # Verify results
    expect(result[:adult]).to be true
    expect(result[:high_balance]).to be true
    expect(result[:premium_account]).to be true
    expect(result[:frequent_buyer]).to be true

    expect(result[:loyalty_offers]).to include("Exclusive Preview")
    expect(result[:loyalty_offers]).to include("Concierge Service")
    expect(result[:loyalty_bonus]).to be > 0

    expect(result[:error_test]).to eq("No Error")
  end
end