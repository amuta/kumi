# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      module TypeRules
        module_function

        # Convert Type objects or symbols to Type objects
        def to_type_object(type_input)
          return type_input if type_input.is_a?(Kumi::Core::Types::Type)

          # Convert symbol/string to Type object
          case type_input
          when :string
            Kumi::Core::Types.scalar(:string)
          when :integer
            Kumi::Core::Types.scalar(:integer)
          when :float
            Kumi::Core::Types.scalar(:float)
          when :boolean
            Kumi::Core::Types.scalar(:boolean)
          when :hash
            Kumi::Core::Types.scalar(:hash)
          when String
            # Handle string type representations like "array<integer>" or "tuple<float, integer>"
            parse_string_type(type_input)
          else
            # For any other type representation, normalize first
            normalized = Kumi::Core::Types.normalize(type_input)
            to_type_object(normalized)
          end
        end

        def parse_string_type(str_type)
          # Handle array types: "array<integer>"
          if (m = /\Aarray<(.+)>\z/.match(str_type))
            element_str = m[1]
            element_type = to_type_object(element_str.to_sym)
            return Kumi::Core::Types.array(element_type)
          end

          # Handle tuple types: "tuple<integer, float>"
          if (m = /\Atuple<(.+)>\z/.match(str_type))
            element_strs = m[1].split(",").map(&:strip)
            element_types = element_strs.map { |s| to_type_object(s.to_sym) }
            return Kumi::Core::Types.tuple(element_types)
          end

          # Try as symbol
          to_type_object(str_type.to_sym)
        end

        def normalize_type_symbol(type_symbol)
          Kumi::Core::Types.normalize(type_symbol)
        end

        # Type promotion for NAST analysis - returns Type objects
        def promote_types(*input_types)
          types = input_types.flatten.compact.uniq
          return Kumi::Core::Types.scalar(:float) if types.any? { |t| float_type?(t) }
          return Kumi::Core::Types.scalar(:integer) if types.any? { |t| integer_type?(t) }

          to_type_object(types.first)
        end

        def common_type(element_types)
          promote_types(element_types)
        end

        def unify_types(type1, type2)
          return type1 if type1 == type2

          promote_types(type1, type2)
        end

        def same_type_as(reference_type)
          to_type_object(reference_type)
        rescue StandardError
          to_type_object(reference_type)
        end

        def array_type(element_type)
          element_obj = to_type_object(element_type)
          Kumi::Core::Types.array(element_obj)
        end

        def tuple_type(*element_types)
          element_objs = element_types.map { |t| to_type_object(t) }
          Kumi::Core::Types.tuple(element_objs)
        end

        # Extract element type from collection Type objects
        def element_type_of(collection_type)
          type_obj = to_type_object(collection_type)

          case type_obj
          when Kumi::Core::Types::ArrayType
            type_obj.element_type
          when Kumi::Core::Types::TupleType
            # Promote all element types to common type
            promote_types(*type_obj.element_types)
          else
            type_obj
          end
        end

        # --- Typed Rule Builders (Direct Type Construction) ---

        # Build rule: return the type of a specific parameter
        def build_same_as(param_name)
          ->(named) { same_type_as(named.fetch(param_name)) }
        end

        # Build rule: promote types of multiple parameters
        def build_promote(*param_names)
          ->(named) { promote_types(*param_names.map { |k| named.fetch(k) }) }
        end

        # Build rule: extract element type from a collection parameter
        def build_element_of(param_name)
          ->(named) { element_type_of(named.fetch(param_name)) }
        end

        # Build rule: unify types of two parameters
        def build_unify(param_name1, param_name2)
          ->(named) { unify_types(named.fetch(param_name1), named.fetch(param_name2)) }
        end

        # Build rule: common type among array elements
        def build_common_type(param_name)
          ->(named) { common_type(named.fetch(param_name)) }
        end

        # Build rule: array of a specific element type
        def build_array(element_type_or_param_name)
          # Check if it's a known scalar kind or Type object
          if element_type_or_param_name.is_a?(Kumi::Core::Types::Type)
            # Type object - use directly
            type_obj = element_type_or_param_name
            ->(_) { Kumi::Core::Types.array(type_obj) }
          elsif element_type_or_param_name.is_a?(Symbol) && Kumi::Core::Types::Validator.valid_kind?(element_type_or_param_name)
            # Known scalar kind - create Type and wrap
            type_obj = to_type_object(element_type_or_param_name)
            ->(_) { Kumi::Core::Types.array(type_obj) }
          else
            # Treat as parameter name reference
            ->(named) { array_type(named.fetch(element_type_or_param_name)) }
          end
        end

        # Build rule: tuple of specific element types
        def build_tuple(*element_types_or_param_names)
          # If single symbol and NOT a known scalar kind, treat as parameter reference
          if element_types_or_param_names.size == 1 && element_types_or_param_names[0].is_a?(Symbol)
            sym = element_types_or_param_names[0]
            unless Kumi::Core::Types::Validator.valid_kind?(sym)
              # Not a known kind - treat as parameter name (holds array of types)
              return ->(named) { tuple_type(*named.fetch(sym)) }
            end
          end

          # Interpret as explicit types
          type_objs = element_types_or_param_names.map { |t| to_type_object(t) }
          ->(_) { Kumi::Core::Types.tuple(type_objs) }
        end

        # Build rule: constant scalar type
        def build_scalar(kind)
          ->(_) { to_type_object(kind) }
        end

        # --- Compile dtype rule string into callable (backward compatible) ---
        def compile_dtype_rule(rule_string, _parameter_names)
          rule = rule_string.to_s.strip

          if (m = /\Aelement_of\((.+)\)\z/.match(rule))
            key = m[1].strip.to_sym
            return build_element_of(key)
          end

          if (m = /\Apromote\((.+)\)\z/.match(rule))
            keys = m[1].split(",").map { |s| s.strip.to_sym }
            return build_promote(*keys)
          end

          if (m = /\Asame_as\((.+)\)\z/.match(rule))
            key = m[1].strip.to_sym
            return build_same_as(key)
          end

          if (m = /\Aunify\(([^,]+),\s*([^)]+)\)\z/.match(rule))
            k1 = m[1].strip.to_sym
            k2 = m[2].strip.to_sym
            return build_unify(k1, k2)
          end

          if (m = /\Acommon_type\((.+)\)\z/.match(rule))
            param_name = m[1].strip.to_sym
            return build_common_type(param_name)
          end

          if (m = /\Aarray\((.+)\)\z/.match(rule))
            inner_rule = m[1].strip
            inner_compiled = compile_dtype_rule(inner_rule, [])
            return ->(named) { array_type(inner_compiled.call(named)) }
          end

          if (m = /\Atuple\(types\((.+)\)\)\z/.match(rule))
            param_name = m[1].strip.to_sym
            return build_tuple(param_name)
          end

          # Constant scalar type
          build_scalar(rule.to_sym)
        end

        def float_type?(t)
          t.is_a?(Kumi::Core::Types::ScalarType) ? t.kind == :float : t == :float
        end

        def integer_type?(t)
          t.is_a?(Kumi::Core::Types::ScalarType) ? t.kind == :integer : t == :integer
        end
      end
    end
  end
end
