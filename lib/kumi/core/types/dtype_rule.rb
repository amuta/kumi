# frozen_string_literal: true

module Kumi
  module Core
    module Types
      # Builds the callables that compute a function's result type from its
      # argument types. Each function definition in data/functions declares a
      # dtype rule (same_as, promote, element_of, ...); the registry loader turns
      # that declaration into one of these callables.
      #
      # A built rule is a lambda taking a Hash of { param_name => Type } and
      # returning the result Type. All type math goes through the TypeSystem, so
      # result-type inference honors the active promotion/category policy.
      module DtypeRule
        module_function

        def type_system
          System.default
        end

        # result type = the type of one named parameter
        def same_as(param)
          ->(named) { named.fetch(param) }
        end

        # result type = promotion of several named parameters
        def promote(*params)
          ->(named) { type_system.promote(*params.map { |p| named.fetch(p) }) }
        end

        # result type = the element type of a collection-typed parameter
        def element_of(param)
          ->(named) { type_system.element_of(named.fetch(param)) }
        end

        # result type = unification of two named parameters
        def unify(param1, param2)
          ->(named) { type_system.unify(named.fetch(param1), named.fetch(param2)) }
        end

        # result type = a constant scalar kind
        def scalar(kind)
          type = ScalarType.new(kind)
          ->(_named) { type }
        end

        # result type = array whose element type comes from a constant kind/Type
        # or from a named parameter
        def array(element_or_param)
          if element_or_param.is_a?(Type)
            type = ArrayType.new(element_or_param)
            ->(_named) { type }
          elsif element_or_param.is_a?(Symbol) && Registry.kind?(element_or_param)
            type = ArrayType.new(ScalarType.new(element_or_param))
            ->(_named) { type }
          else
            ->(named) { ArrayType.new(named.fetch(element_or_param)) }
          end
        end

        # result type = tuple of constant element types, or a tuple whose element
        # types are held in a named parameter (an array of Types)
        def tuple(*elements_or_param)
          if elements_or_param.size == 1 && elements_or_param.first.is_a?(Symbol) &&
             !Registry.kind?(elements_or_param.first)
            param = elements_or_param.first
            return ->(named) { TupleType.new(Array(named.fetch(param))) }
          end

          types = elements_or_param.map { |e| e.is_a?(Type) ? e : ScalarType.new(e) }
          ->(_named) { TupleType.new(types) }
        end
      end
    end
  end
end
