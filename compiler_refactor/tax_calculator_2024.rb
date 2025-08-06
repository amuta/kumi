#!/usr/bin/env ruby

require_relative "ir_test_helper"

module Tax2024
  FED_BREAKS_SINGLE   = [11_600, 47_150, 100_525, 191_950,
                         243_725, 609_350, Float::INFINITY].freeze

  FED_BREAKS_MARRIED  = [23_200, 94_300, 201_050, 383_900,
                         487_450, 731_200, Float::INFINITY].freeze

  FED_BREAKS_SEPARATE = [11_600, 47_150, 100_525, 191_950,
                         243_725, 365_600, Float::INFINITY].freeze

  FED_BREAKS_HOH      = [16_550, 63_100, 100_500, 191_950,
                         243_700, 609_350, Float::INFINITY].freeze

  FED_RATES           = [0.10, 0.12, 0.22, 0.24,
                         0.32, 0.35, 0.37].freeze
end

module FederalTaxCalculator
  extend Kumi::Schema
  include Tax2024

  schema skip_compiler: true do
    input do
      float  :income
      string :filing_status, domain: %w[single married_joint married_separate head_of_household]
    end

    # ── standard deduction table ───────────────────────────────────────
    trait :single,     input.filing_status == "single"
    trait :married,    input.filing_status == "married_joint"
    trait :separate,   input.filing_status == "married_separate"
    trait :hoh,        input.filing_status == "head_of_household"

    value :std_deduction do
      on  single,   14_600
      on  married,  29_200
      on  separate, 14_600
      base           21_900 # HOH default
    end

    # Use clamp to ensure non-negative (max(x, 0) = clamp(x, 0, infinity))
    value :taxable_income, fn(:clamp, input.income - std_deduction, 0, 999_999_999)

    # For debugging, let's use a simple literal array first
    value :fed_breaks do
      on  single,   [11_600, 47_150]  # Simplified for testing
      on  married,  FED_BREAKS_MARRIED
      on  separate, FED_BREAKS_SEPARATE
      on  hoh,      FED_BREAKS_HOH
    end

    value :fed_rates, FED_RATES
    
    # For now, skip piecewise_sum since it's complex
    # We'll calculate a simplified version
    
    # ── FICA (employee share) ─────────────────────────────────────────────
    value :ss_wage_base, 168_600.0
    value :ss_rate,      0.062

    value :med_base_rate, 0.0145
    value :addl_med_rate, 0.009

    # additional‑Medicare threshold depends on filing status
    value :addl_threshold do
      on  single,   200_000
      on  married,  250_000
      on  separate, 125_000
      base           200_000 # HOH same as single
    end

    # social‑security portion (capped) - min(income, cap) = clamp(income, 0, cap)
    value :ss_tax, fn(:clamp, input.income, 0, ss_wage_base) * ss_rate

    # medicare (1.45 % on everything)
    value :med_tax, input.income * med_base_rate

    # additional medicare on income above threshold
    value :addl_med_tax, fn(:clamp, input.income - addl_threshold, 0, 999_999_999) * addl_med_rate

    value :fica_tax,  ss_tax + med_tax + addl_med_tax
    # Protect against divide by zero
    trait :has_income, input.income > 0
    value :fica_eff do
      on has_income, fica_tax / input.income
      base 0.0
    end
    
    # ── Simplified fed tax (flat rate for demo) ──────────────────────
    # Using a simplified calculation for the demo
    value :fed_tax do
      on single,   taxable_income * 0.22
      on married,  taxable_income * 0.20
      on separate, taxable_income * 0.22
      base         taxable_income * 0.21
    end
    
    value :fed_eff do
      on has_income, fed_tax / input.income
      base 0.0
    end

    # ── Totals ─────────────────────────────────────────────────────────
    value :total_tax, fed_tax + fica_tax
    value :total_eff do
      on has_income, total_tax / input.income
      base 0.0
    end
    value :after_tax, input.income - total_tax
  end
end

def print_tax_summary(income:, filing_status:)
  test_data = { income: income.to_f, filing_status: filing_status }
  
  result = IRTestHelper.compile_schema(FederalTaxCalculator, debug: false)
  compiled = result[:compiled_schema]
  
  # Calculate all values
  std_ded = compiled.bindings[:std_deduction].call(test_data)
  taxable = compiled.bindings[:taxable_income].call(test_data)
  ss_tax = compiled.bindings[:ss_tax].call(test_data)
  med_tax = compiled.bindings[:med_tax].call(test_data)
  addl_med = compiled.bindings[:addl_med_tax].call(test_data)
  fica_tax = compiled.bindings[:fica_tax].call(test_data)
  fica_eff = compiled.bindings[:fica_eff].call(test_data)
  fed_tax = compiled.bindings[:fed_tax].call(test_data)
  fed_eff = compiled.bindings[:fed_eff].call(test_data)
  total_tax = compiled.bindings[:total_tax].call(test_data)
  total_eff = compiled.bindings[:total_eff].call(test_data)
  after_tax = compiled.bindings[:after_tax].call(test_data)
  
  puts "=" * 60
  puts "Federal Tax Calculation for 2024"
  puts "=" * 60
  puts "Income:         $#{'%12.2f' % income}"
  puts "Filing Status:  #{filing_status}"
  puts "-" * 60
  
  puts "\n📊 Deductions & Taxable Income"
  puts "Standard Deduction:  $#{'%12.2f' % std_ded}"
  puts "Taxable Income:      $#{'%12.2f' % taxable}"
  
  puts "\n💰 FICA Taxes"
  puts "Social Security:     $#{'%12.2f' % ss_tax}"
  puts "Medicare:            $#{'%12.2f' % med_tax}"
  puts "Additional Medicare: $#{'%12.2f' % addl_med}"
  puts "Total FICA:          $#{'%12.2f' % fica_tax} (#{'%.2f' % (fica_eff * 100)}%)"
  
  puts "\n🏛️  Federal Income Tax"
  puts "Federal Tax:         $#{'%12.2f' % fed_tax} (#{'%.2f' % (fed_eff * 100)}%)"
  
  puts "\n📈 Totals"
  puts "Total Tax:           $#{'%12.2f' % total_tax} (#{'%.2f' % (total_eff * 100)}%)"
  puts "After-Tax Income:    $#{'%12.2f' % after_tax}"
  puts "=" * 60
end

# Test with different scenarios
scenarios = [
  { income: 50_000, filing_status: "single" },
  { income: 100_000, filing_status: "married_joint" },
  { income: 250_000, filing_status: "single" },
  { income: 500_000, filing_status: "married_joint" }
]

scenarios.each do |scenario|
  print_tax_summary(**scenario)
  puts "\n"
end