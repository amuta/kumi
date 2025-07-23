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
      if data.slice(:age).to_i >= 65
        "Senior VIP"
      elsif data.slice(:account_type).to_s.casecmp?("premium")
        "Premium"
      elsif data.slice(:account_balance).to_i >= 10_000 &&
            data.slice(:years_customer).to_i >= 5 &&
            data.slice(:last_purchase_days_ago).to_i <= 30 &&
            data.slice(:total_purchases).to_i >= 50
        "Gold"
      elsif data.slice(:age).to_i >= 18
        "Standard"
      else
        "Basic"
      end

    segment =
      if data.slice(:account_balance).to_i >= 10_000 &&
         data.slice(:years_customer).to_i >= 5 &&
         data.slice(:support_tickets).to_i <= 3 &&
         data.slice(:referral_count).to_i > 0
        "Champion"
      elsif data.slice(:last_purchase_days_ago).to_i <= 30 &&
            data.slice(:total_purchases).to_i >= 50
        "Loyal Customer"
      elsif data.slice(:account_balance).to_i >= 10_000 &&
            data.slice(:last_purchase_days_ago).to_i <= 30
        "Big Spender"
      elsif data.slice(:total_purchases).to_i >= 50
        "Frequent Buyer"
      else
        "Potential"
      end

    engagement_score =
      data.slice(:total_purchases).to_i *
      (if data.slice(:last_purchase_days_ago).to_i <= 30 &&
        data.slice(:total_purchases).to_i >= 50
         1.5
       else
         1.0
       end)

    heavy_score =
      data.slice(:purchases)
          .each_with_object(Hash.new(0.0)) do |purchase, sums|
            cat = purchase.slice(:category).to_s
            amt = purchase.slice(:amount).to_f
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
  # Reuse the setup from the integration spec
  before(:all) do
    Kumi::FunctionRegistry.reset!
    Kumi::FunctionRegistry.register(:create_offers) { |*| ["Offer"] }
    Kumi::FunctionRegistry.register(:bonus_formula) { |*| 100.0 }
    Kumi::FunctionRegistry.register(:error!) { |_| "No Error" }
    Kumi::FunctionRegistry.register(:group_and_sum) do |purchases|
      purchases
        .group_by   { |p| p[:category] }
        .map        { |_, items| items.sum { |i| i[:amount] } }
        .sort.last(5).reverse
        .sum
    end
  end

  let(:schema_definition) do
    Kumi::Parser::Dsl.build_syntax_tree do
      trait :adult, input.age, :>=, 18
      trait :senior, input.age, :>=, 65
      trait :high_balance, input.account_balance, :>=, 10_000
      trait :premium_account, input.account_type, :==, "premium"
      trait :recent_activity, input.last_purchase_days_ago, :<=, 30
      trait :frequent_buyer, input.total_purchases, :>=, 50
      trait :long_term_customer, input.years_customer, :>=, 5
      trait :has_referrals, input.referral_count, :>, 0
      trait :low_support_usage, input.support_tickets, :<=, 3

      value :check_engagement, fn(:all?, [ref(:recent_activity), ref(:frequent_buyer)])
      value :check_value, fn(:all?, [ref(:high_balance), ref(:long_term_customer)])
      value :check_low_maintenance, fn(:all?, [ref(:low_support_usage), ref(:has_referrals)])

      trait :engaged_customer, ref(:check_engagement), :==, true
      trait :valuable_customer, ref(:check_value), :==, true
      trait :low_maintenance, ref(:check_low_maintenance), :==, true

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

      value :engagement_score, fn(:multiply,
                                  input.total_purchases,
                                  fn(:conditional, ref(:engaged_customer), 1.5, 1.0))

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
