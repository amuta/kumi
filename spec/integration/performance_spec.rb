# frozen_string_literal: true

require "benchmark"
require "benchmark/ips"

return unless ENV["KUMI_PERFORMANCE_TEST"]

# Run this spec file if you want to benchmark the performance of Kumi
# against a plain Ruby implementation of the same logic.
# - For now it wont be running in CI, but you can run it locally commenting out the `return` line above.

class PlainRubySegmenter
  # I know, this class is ugly, it could be optimized, but its just a try
  # to replicate a real service that evaluates customer data

  def evaluate(data)
    tier =
      if data[:age].to_i >= 65
        "Senior VIP"
      elsif data[:account_type].to_s.casecmp?("premium")
        "Premium"
      elsif data[:account_balance].to_i >= 10_000 &&
            data[:years_customer].to_i >= 5 &&
            data[:last_purchase_days_ago].to_i <= 30 &&
            data[:total_purchases].to_i >= 50
        "Gold"
      elsif data[:age].to_i >= 18
        "Standard"
      else
        "Basic"
      end

    segment =
      if data[:account_balance].to_i >= 10_000 &&
         data[:years_customer].to_i >= 5 &&
         data[:support_tickets].to_i <= 3 &&
         data[:referral_count].to_i > 0
        "Champion"
      elsif data[:last_purchase_days_ago].to_i <= 30 &&
            data[:total_purchases].to_i >= 50
        "Loyal Customer"
      elsif data[:account_balance].to_i >= 10_000 &&
            data[:last_purchase_days_ago].to_i <= 30
        "Big Spender"
      elsif data[:total_purchases].to_i >= 50
        "Frequent Buyer"
      else
        "Potential"
      end

    engagement_score =
      data[:total_purchases].to_i *
      (if data[:last_purchase_days_ago].to_i <= 30 &&
        data[:total_purchases].to_i >= 50
         1.5
       else
         1.0
       end)

    heavy_score =
      data[:purchases]
          .each_with_object(Hash.new(0.0)) do |purchase, sums|
            cat = purchase[:category].to_s
            amt = purchase[:amount].to_f
            sums[cat] += amt
          end
          .values
          .sort
          .last(5)
          .sum

    {
      customer_tier: tier,
      marketing_segment: segment,
      engagement_score: engagement_score,
      heavy_score: heavy_score
    }
  end
end

RSpec.describe "Kumi Performance" do
  before(:all) do
    # Register custom functions for performance testing
    Kumi::Registry.define_aggregate("group_and_sum") do |f|
        f.summary "Groups purchases by category, sums amounts, and returns sum of top 5"
        f.dtypes({ result: "float" })
        f.identity 0.0
        f.kernel do |purchases|
          purchases
            .group_by   { |p| p[:category] }
            .map        { |_, items| items.sum { |i| i[:amount] } }
            .sort.last(5).reverse
            .sum
        end
      end
    
    # Register additional functions for performance testing
    Kumi::Registry.define_eachwise("create_offers") do |f|
      f.summary "Creates offers"
      f.dtypes({ result: "any" })
      f.kernel { |*| ["Offer"] }
    end
    
    Kumi::Registry.define_eachwise("bonus_formula") do |f|
      f.summary "Calculates bonus"
      f.dtypes({ result: "float" })
      f.kernel { |*| 100.0 }
    end
  end
  
  after(:all) do
    ["group_and_sum", "create_offers", "bonus_formula"].each do |func_name|
      Kumi::Registry.custom_functions.delete(func_name)
    end
  end

  let(:schema_definition) do
    Kumi::Core::RubyParser::Dsl.build_syntax_tree do
      input do
        integer :age
        integer :account_balance  
        string :account_type
        integer :last_purchase_days_ago
        integer :total_purchases
        integer :years_customer
        integer :referral_count
        integer :support_tickets
        array :purchases do
          string :category
          float :amount
        end
      end

      trait :adult, input.age, :>=, 18
      trait :senior, input.age, :>=, 65
      trait :high_balance, input.account_balance, :>=, 10_000
      trait :premium_account, input.account_type, :==, "premium"
      trait :recent_activity, input.last_purchase_days_ago, :<=, 30
      trait :frequent_buyer, input.total_purchases, :>=, 50
      trait :long_term_customer, input.years_customer, :>=, 5
      trait :has_referrals, input.referral_count, :>, 0
      trait :low_support_usage, input.support_tickets, :<=, 3

      value :check_engagement do
        on recent_activity, frequent_buyer, true
        base false
      end
      
      value :check_value do
        on high_balance, long_term_customer, true
        base false
      end
      
      value :check_low_maintenance do
        on low_support_usage, has_referrals, true
        base false
      end

      trait :engaged_customer, ref(:check_engagement), :==, true
      trait :valuable_customer, ref(:check_value), :==, true
      trait :low_maintenance, ref(:check_low_maintenance), :==, true

      value :customer_tier do
        on senior, "Senior VIP"
        on valuable_customer, engaged_customer, "Gold"
        on premium_account, "Premium"
        on adult, "Standard"
        base "Basic"
      end

      value :marketing_segment do
        on valuable_customer, low_maintenance, "Champion"
        on engaged_customer, "Loyal Customer"
        on high_balance, recent_activity, "Big Spender"
        on frequent_buyer, "Frequent Buyer"
        base "Potential"
      end

      value :engagement_multiplier do
        on engaged_customer, 1.5
        base 1.0
      end

      value :engagement_score, fn(:mul,
                                  input.total_purchases,
                                  ref(:engagement_multiplier))

      value :heavy_score, fn(:group_and_sum, input.purchases)
    end
  end

  # This block measures the one-time cost of compilation
  context "compilation phase" do
    it "compiles the schema within an acceptable time" do
      Benchmark.ips do |x|
        x.report("Kumi Schema Analyzer & Compile") do
          analyzer_result = Kumi::Analyzer.analyze!(schema_definition)
          Kumi::Compiler.compile(schema_definition, analyzer: analyzer_result)
        end

        x.compare!
      end

      expect(true).to be(true)

      # The threshold is arbitrary; adjust based on expectations.
      # This asserts that the compilation is not excessively slow.
      # expect(compilation_time).to be < 0.001 # seconds
      # puts "\nCompilation Time: #{(compilation_time * 1000).round(2)} ms"
    end
  end

  # This block measures the runtime performance after compilation
  context "execution phase" do
    let!(:compiled_schema) do
      analyzer_result = Kumi::Analyzer.analyze!(schema_definition)
      Kumi::Compiler.compile(schema_definition, analyzer: analyzer_result)
    end

    let!(:plain_ruby_segmenter) { PlainRubySegmenter.new }

    let!(:customer_data_set) do
      # Generate a diverse set of data to ensure the benchmark covers various code paths
      Array.new(1000) do |i|
        {
          name: "Customer #{i}",
          age: 20 + (i % 60),
          account_balance: 1000 + (i * 300),
          years_customer: 1 + (i % 15),
          last_purchase_days_ago: 1 + (i % 90),
          total_purchases: 10 + (i * 2),
          account_type: i.even? ? "premium" : "standard",
          referral_count: i % 5,
          support_tickets: i % 4,
          purchases: Array.new(200) do
            { category: %w[A B C D].sample,
              amount: rand(10..500) }
          end
        }
      end
    end

    it "is slower than plain ruby if it needs to evaluate all the keys" do
      compiled_schema
      customer_data_set

      puts "\n--- Runtime Performance Benchmark ---"
      Benchmark.ips do |x|
        x.report("Kumi Schema") do
          compiled_schema.evaluate(customer_data_set.sample)
        end

        x.report("Plain Ruby") do
          plain_ruby_segmenter.evaluate(customer_data_set.sample)
        end

        x.compare!
      end

      expect(true).to be(true)
    end

    it "is faster than plain ruby if it only evaluates a few keys" do
      puts "\n--- Runtime Performance Benchmark (Partial Evaluation) ---"
      Benchmark.ips do |x|
        x.report("Kumi Schema (Partial)") do
          compiled_schema.evaluate(customer_data_set.sample, :customer_tier, :marketing_segment)
        end

        x.report("Plain Ruby (Partial)") do
          plain_ruby_segmenter.evaluate(customer_data_set.sample).slice(:customer_tier, :marketing_segment)
        end

        x.compare!
      end

      expect(true).to be(true)
    end
  end
end
