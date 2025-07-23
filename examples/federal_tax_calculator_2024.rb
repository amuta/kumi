# U.S. federal income‑tax plus FICA

require_relative "../lib/kumi"

module CompositeTax2024
  extend Kumi::Schema
  FED_BREAKS_SINGLE   = [11_600, 47_150, 100_525, 191_950,
                         243_725, 609_350, Float::INFINITY]

  FED_BREAKS_MARRIED  = [23_200, 94_300, 201_050, 383_900,
                         487_450, 731_200, Float::INFINITY]

  FED_BREAKS_SEPARATE = [11_600, 47_150, 100_525, 191_950,
                         243_725, 365_600, Float::INFINITY]

  FED_BREAKS_HOH      = [16_550, 63_100, 100_500, 191_950,
                         243_700, 609_350, Float::INFINITY]
  
  FED_RATES           = [0.10, 0.12, 0.22, 0.24,
                         0.32, 0.35, 0.37]

  schema do
    input do
      float  :income
      string :filing_status
    end

    # ── standard deduction table ───────────────────────────────────────
    trait :single,     input.filing_status == "single"
    trait :married,    input.filing_status == "married_joint"
    trait :separate,   input.filing_status == "married_separate"
    trait :hoh,        input.filing_status == "head_of_household"

    value :std_deduction do
      on  :single,   14_600
      on  :married,  29_200
      on  :separate, 14_600
      base           21_900 # HOH default
    end

    value :taxable_income,
          fn(:max, [input.income - std_deduction, 0])

    # ── FEDERAL brackets (single shown; others similar if needed) ──────
    value :fed_breaks do
      on  :single,   FED_BREAKS_SINGLE
      on  :married,  FED_BREAKS_MARRIED
      on  :separate, FED_BREAKS_SEPARATE
      on  :hoh,      FED_BREAKS_HOH
    end

    value :fed_rates,  FED_RATES
    value :fed_calc,
          fn(:piecewise_sum, taxable_income, fed_breaks, fed_rates)

    value :fed_tax,       fed_calc[0]
    value :fed_marginal,  fed_calc[1]
    value :fed_eff,       fed_tax / fn(:max, [input.income, 1.0])

    # ── FICA (employee share) ─────────────────────────────────────────────
    value :ss_wage_base, 168_600.0
    value :ss_rate,      0.062

    value :med_base_rate, 0.0145
    value :addl_med_rate, 0.009

    # additional‑Medicare threshold depends on filing status
    value :addl_threshold do
      on  :single,   200_000
      on  :married,  250_000
      on  :separate, 125_000
      base           200_000 # HOH same as single
    end

    # social‑security portion (capped)
    value :ss_tax,
          fn(:min, [input.income, ss_wage_base]) * ss_rate

    # medicare (1.45 % on everything)
    value :med_tax, input.income * med_base_rate

    # additional medicare on income above threshold
    value :addl_med_tax,
          fn(:max, [input.income - addl_threshold, 0]) * addl_med_rate

    value :fica_tax,  ss_tax + med_tax + addl_med_tax
    value :fica_eff,  fica_tax / fn(:max, [input.income, 1.0])

    # ── Totals ─────────────────────────────────────────────────────────
    value :total_tax,
          fed_tax + fica_tax

    value :total_eff,   total_tax / fn(:max, [input.income, 1.0])
    value :after_tax,   input.income - total_tax
  end
end

def example(income: 1_000_000, status: "single")
  # Create a runner for the schema
  r = CompositeTax2024.from(income: income, filing_status: status)
  # puts r.inspect
  puts "\n=== 2024 U.S. Income‑Tax Example ==="
  printf "Income:                      $%0.2f\n", income
  puts   "Filing status:               #{status}\n\n"

  puts "Federal tax:             $#{r[:fed_tax].round(2)} (#{(r[:fed_eff] * 100).round(2)}% effective)"
  puts "FICA tax:                $#{r[:fica_tax].round(2)} (#{(r[:fica_eff] * 100).round(2)}% effective)"
  puts "Total tax:               $#{r[:total_tax].round(2)} (#{(r[:total_eff] * 100).round(2)}% effective)"
  puts "After-tax income:        $#{r[:after_tax].round(2)}"
end

example
