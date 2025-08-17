# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      module DTypeAdapter
        module_function

        # Public entry: compute result dtype from a function definition and argument types.
        # - fn: a RegistryV2 function object (must expose #name, #dtypes, #type_vars, #class_sym)
        # - arg_types: Array<Symbol|Hash> inferred by the caller (e.g., [:float], [{:array=>:integer}], ...)
        #
        def evaluate(fn, arg_types)
          expr = (fn.dtypes && (fn.dtypes[:result] || fn.dtypes['result']))
          return nil unless expr

          # Aggregates talk about *element* types; unwrap 1 level for dtype eval
          types = aggregate?(fn) ? arg_types.map { element_type_of(_1) } : arg_types

          compile(expr).call(types, fn)
        end

        # Optional: precompile at registry load time and stash on the function:
        #   fn.result_type_fn = DTypeAdapter.compile(expr)
        # …then evaluate = fn.result_type_fn.call(types, fn)
        def compile(expr)
          expr = expr.to_s.strip

          # Fast paths
          return ->(_types, _fn) { :float }   if expr.start_with?('promote_float(')
          return ->(_types, _fn) { :boolean } if expr == 'bool' || expr == 'boolean'
          return ->(_types, _fn) { :integer } if expr == 'int' || expr == 'integer'
          return ->(_types, _fn) { :float }   if expr == 'float'
          return ->(types, _fn) { types.first } if expr == 'T' # degenerate: echo first type-var

          # Parameterized patterns
          case expr
          when /\Apromote\(([^)]+)\)\z/i
            # promote(T,U,...) → float if any float; else integer
            ->(types, _fn) do
              # If author wrote promote(T) for aggregates, we still use the provided `types`
              any_float = types.any? { |t| t == :float }
              any_float ? :float : :integer
            end

          when /\Aunify\(([^)]+)\)\z/i
            ->(types, _fn) { types.reduce { |acc, t| Kumi::Core::Types.unify(acc, t) } }

          else
            # Unknown → nil (caller can fall back or keep :any)
            ->(_types, _fn) { nil }
          end
        end

        def aggregate?(fn)
          (fn.respond_to?(:class_sym) && fn.class_sym == :aggregate) ||
          (fn.respond_to?(:class_name) && fn.class_name.to_s == 'aggregate') ||
          (fn.respond_to?(:fn_class)   && fn.fn_class.to_s   == 'aggregate') ||
          (fn.respond_to?(:klass)      && fn.klass.to_s      == 'aggregate')
        end

        def element_type_of(t)
          t.is_a?(Hash) && t[:array] ? t[:array] : t
        end
      end
    end
  end
end