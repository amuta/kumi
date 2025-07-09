# frozen_string_literal: true

module SchemaGenerator
  # Generates a Kumi schema with:
  # - `num_preds` simple predicates
  # - `num_vals` value rules, each with `cascade_size` on-clauses
  # Fields are drawn from a fixed pool so you only need to supply those once at evaluation time.
  def generate_schema(
    num_preds:     500,
    num_vals:      500,
    cascade_size:  4,
    fields:        %i[age balance purchases]
  )
    Kumi::Parser::Dsl.schema do
      # simple predicates
      num_preds.times do |i|
        predicate(
          :"pred_#{i}",
          key(fields[i % fields.size]),
          :>=,
          i % 100 # threshold cycles 0–99
        )
      end

      # values with cascades
      num_vals.times do |j|
        value :"val_#{j}" do
          cascade_size.times do |k|
            # pick a predicate to branch on
            pred = :"pred_#{(j + k) % num_preds}"
            # result is just a string unique per branch
            on pred, "res_#{j}_#{k}"
          end
          base "default_#{j}"
        end
      end

      # final value that depends on all values
      value :final_value do
        # just sum all values
        fn(:sum, fields.map { |f| ref(:"val_#{f}") })
      end
    end
  end
end

RSpec.configure do |c|
  c.include SchemaGenerator
end
