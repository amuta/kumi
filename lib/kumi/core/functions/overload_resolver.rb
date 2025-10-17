# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # OverloadResolver handles type-aware function overload resolution
      # Given a function alias/id and argument types, finds the best matching function
      #
      # Responsibilities:
      # - Track all function overloads per alias
      # - Match argument types against parameter constraints
      # - Provide clear error messages when resolution fails
      class OverloadResolver
        def initialize(functions_by_id)
          @functions = functions_by_id                # "core.mul" => Function
          @by_id = functions_by_id                    # Direct lookup
          @alias_overloads = build_alias_overloads(functions_by_id)
        end

        # Resolve a function alias or ID to a specific function ID based on argument types
        #
        # @param alias_or_id [String, Symbol] Function alias or full function ID
        # @param arg_types [Array<Symbol>] Inferred types of arguments
        # @return [String] The resolved function_id
        # @raise [ResolutionError] If function cannot be resolved
        def resolve(alias_or_id, arg_types)
          s = alias_or_id.to_s

          # If it's already a full function ID, validate and return it
          if @functions.key?(s)
            validate_arity!(s, arg_types)
            return s
          end

          # Get all candidate overloads for this alias
          candidates = @alias_overloads[s]
          raise ResolutionError, "unknown function #{alias_or_id}" if candidates.nil?

          # Single overload - use it directly
          if candidates.size == 1
            validate_arity!(candidates.first, arg_types)
            return candidates.first
          end

          # Multiple overloads - find best match by type constraints (prefer exact matches)
          candidates_with_scores = candidates.map do |fn_id|
            fn = @functions[fn_id]
            score = match_score(fn.params, arg_types)
            [fn_id, score]
          end

          best_match, score = candidates_with_scores.max_by { |_, s| s }

          if score > 0
            return best_match
          end

          # No match found - provide helpful error
          available = candidates.map { |id| @functions[id].id }.join(", ")
          raise ResolutionError,
                "no overload of '#{alias_or_id}' matches argument types #{arg_types.inspect}. " \
                "Available overloads: #{available}"
        end

        # Get function object by ID (already resolved)
        def function(id)
          @functions.fetch(id) do
            raise ResolutionError, "unknown function #{id}"
          end
        end

        # Check if a function exists
        def exists?(id)
          @functions.key?(id.to_s)
        end

        private

        def build_alias_overloads(functions)
          # Maps each alias to an array of all function_ids that have that alias
          functions.values.each_with_object({}) do |func, acc|
            func.aliases.each do |al|
              acc[al] ||= []
              acc[al] << func.id
            end
          end
        end

        def params_match?(params, arg_types)
          # Check arity first
          return false if params.size != arg_types.size

          # Check each parameter constraint
          params.zip(arg_types).all? do |param, arg_type|
            param_dtype = param["dtype"]
            param_dtype.nil? || type_compatible?(param_dtype, arg_type)
          end
        end

        def match_score(params, arg_types)
          # Returns match quality: higher is better
          # 0 = no match, 1 = matches with unconstrained params, 2 = exact match
          return 0 unless params_match?(params, arg_types)

          # Count exact constraint matches (all arg_types are Type objects now)
          exact_matches = params.zip(arg_types).count do |param, arg_type|
            param_dtype = param["dtype"]
            score_type_object_match(param_dtype, arg_type)
          end

          exact_matches
        end

        def score_type_object_match(param_dtype, type_obj)
          case param_dtype&.to_s
          when "string"
            type_obj.is_a?(Kumi::Core::Types::ScalarType) && type_obj.kind == :string
          when "array"
            type_obj.is_a?(Kumi::Core::Types::ArrayType)
          when "integer"
            type_obj.is_a?(Kumi::Core::Types::ScalarType) && type_obj.kind == :integer
          when "float"
            type_obj.is_a?(Kumi::Core::Types::ScalarType) && type_obj.kind == :float
          when "hash"
            type_obj.is_a?(Kumi::Core::Types::ScalarType) && type_obj.kind == :hash
          else
            false
          end
        end

        def type_compatible?(param_dtype_str, arg_type)
          raise ArgumentError, "arg_type must be a Type object, got #{arg_type.inspect}" unless arg_type.is_a?(Kumi::Core::Types::Type)

          case param_dtype_str
          when "string"
            arg_type.is_a?(Kumi::Core::Types::ScalarType) && arg_type.kind == :string
          when "array"
            arg_type.is_a?(Kumi::Core::Types::ArrayType)
          when "integer"
            arg_type.is_a?(Kumi::Core::Types::ScalarType) && arg_type.kind == :integer
          when "float"
            arg_type.is_a?(Kumi::Core::Types::ScalarType) && arg_type.kind == :float
          when "hash"
            arg_type.is_a?(Kumi::Core::Types::ScalarType) && arg_type.kind == :hash
          else
            # No constraint, any type matches
            true
          end
        end

        def validate_arity!(fn_id, arg_types)
          fn = @functions[fn_id]
          return if fn.params.size == arg_types.size

          raise ResolutionError,
                "function #{fn_id} expects #{fn.params.size} arguments, got #{arg_types.size}"
        end

        # Custom error for function resolution failures
        class ResolutionError < StandardError; end
      end
    end
  end
end
