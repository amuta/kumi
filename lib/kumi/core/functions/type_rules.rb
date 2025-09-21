# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      module TypeRules
        module_function

        def normalize_type_symbol(type_symbol)
          Kumi::Core::Types.normalize(type_symbol)
        end

        # Minimal type promotion for NAST analysis
        def promote_types(*input_types)
          normalized = input_types.flatten.compact.uniq
          return :float if normalized.include?(:float)
          return :integer if normalized.include?(:integer)

          normalized.first
        end

        def common_type(element_types)
          promote_types(element_types)
        end

        def unify_types(type1, type2)
          return type1 if type1 == type2

          promote_types(type1, type2) # Fall back to promotion for now
        end

        def same_type_as(reference_type_symbol)
          normalize_type_symbol(reference_type_symbol)
        rescue StandardError
          # binding.pry
          raise
        end

        def array_type(element_type)
          :"array<#{element_type}>"
        end

        def tuple_type(*element_types)
          :"tuple<#{element_types.join(', ')}>"
        end

        # Parses a collection type symbol to find its element type.
        def element_type_of(collection_type)
          str_type = collection_type.to_s
          if (m = /\Aarray<(.+)>\z/.match(str_type))
            return m[1].to_sym
          end

          if (m = /\Atuple<(.+)>\z/.match(str_type))
            # The "element type" of a tuple is the common promoted type of its members.
            # e.g., tuple<integer, float> -> float
            member_types = m[1].split(",").map { |s| s.strip.to_sym }
            return promote_types(member_types)
          end

          normalize_type_symbol(str_type)
        end

        # Compile dtype rule string into callable
        def compile_dtype_rule(rule_string, _parameter_names)
          rule = rule_string.to_s.strip

          # --- NEW: Handle the "element_of" rule ---
          if (m = /\Aelement_of\((.+)\)\z/.match(rule))
            key = m[1].strip.to_sym
            return ->(named) { element_type_of(named.fetch(key)) }
          end

          # Handle existing function-based rules
          if (m = /\Apromote\((.+)\)\z/.match(rule))
            keys = m[1].split(",").map { |s| s.strip.to_sym }
            return ->(named) { promote_types(*keys.map { |k| named.fetch(k) }) }
          end
          if (m = /\Asame_as\((.+)\)\z/.match(rule))
            key = m[1].strip.to_sym
            return ->(named) { same_type_as(named.fetch(key)) }
          end
          if (m = /\Aunify\(([^,]+),\s*([^)]+)\)\z/.match(rule)) # TODO: - check if needed or is just the promote
            k1 = m[1].strip.to_sym
            k2 = m[2].strip.to_sym
            return ->(named) { unify_types(named.fetch(k1), named.fetch(k2)) }
          end
          if (m = /\Acommon_type\((.+)\)\z/.match(rule))
            param_name = m[1].strip.to_sym
            return ->(named) { common_type(named.fetch(param_name)) }
          end
          if (m = /\Aarray\((.+)\)\z/.match(rule))
            inner_rule = m[1].strip
            inner_compiled = compile_dtype_rule(inner_rule, []) # param_names not needed here
            return ->(named) { array_type(inner_compiled.call(named)) }
          end
          if (m = /\Atuple\(types\((.+)\)\)\z/.match(rule))
            param_name = m[1].strip.to_sym
            return ->(named) { tuple_type(*named.fetch(param_name)) }
          end

          ->(_) { normalize_type_symbol(rule.to_sym) }
        end
      end
    end
  end
end
