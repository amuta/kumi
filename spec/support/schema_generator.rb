# frozen_string_literal: true

module SchemaGenerator
  # Generates a Kumi schema with:
  # - `num_traits` simple traits
  # - `num_vals` value rules, each with `cascade_size` on-clauses
  # Fields are drawn from a fixed pool so you only need to supply those once at evaluation time.
  def generate_schema(
    num_traits: 500,
    num_vals:      500,
    cascade_size:  4,
    fields:        %i[age balance purchases]
  )
    Kumi::Core::RubyParser::Dsl.build_syntax_tree do
      input do
        fields.each do |field|
          key field, type: Kumi::Core::Types::INT
        end
      end

      # simple traits
      num_traits.times do |i|
        trait(
          :"trait_#{i}",
          input.send(fields[i % fields.size]),
          :>=,
          i % 100 # threshold cycles 0–99
        )
      end

      # values with cascades
      num_vals.times do |j|
        value :"val_#{j}" do
          cascade_size.times do |k|
            # pick a trait to branch on
            trait = :"trait_#{(j + k) % num_traits}"
            # result is just a string unique per branch
            on trait, "res_#{j}_#{k}"
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

  # Helper to create a schema with proper analysis and compilation
  def create_schema(&block)
    syntax_tree = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&block)
    analyzer = Kumi::Analyzer.analyze!(syntax_tree)
    compiled = Kumi::Compiler.compile(syntax_tree, analyzer: analyzer)

    # Create a schema-like object that includes the from method
    schema = OpenStruct.new(
      syntax_tree: syntax_tree,
      analysis: analyzer,
      compiled: compiled,
      runner: Kumi::Core::SchemaInstance.new(compiled, analyzer.definitions, {})
    )

    # Add the from method with input validation (type + domain)
    def schema.from(context)
      input_meta = analysis.state[:inputs] || {}
      violations = Kumi::Core::Input::Validator.validate_context(context, input_meta)

      raise Kumi::Core::Errors::InputValidationError, violations unless violations.empty?

      Kumi::Core::SchemaInstance.new(compiled, analysis.definitions, context)
    end

    schema
  end
end

RSpec.shared_context "schema generator" do
  include SchemaGenerator
end

RSpec.configure do |c|
  c.include SchemaGenerator
end
