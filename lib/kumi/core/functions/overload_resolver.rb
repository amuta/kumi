# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # Type-aware function overload resolution. Given a function alias/id and the
      # inferred argument types, picks the overload whose parameter constraints
      # best match. All constraint matching goes through Types::System, so the
      # set of accepted kinds (and any per-target policy) lives in one place.
      class OverloadResolver
        def initialize(functions_by_id, type_system: Kumi::Core::Types::System.default)
          @functions = functions_by_id
          @alias_overloads = build_alias_overloads(functions_by_id)
          @types = type_system
        end

        # Resolve an alias or id to a concrete function id based on arg types.
        # Raises ResolutionError (with a precise, argument-level message) on an
        # arity or type mismatch.
        def resolve(alias_or_id, arg_types)
          id = alias_or_id.to_s
          return resolve_single(alias_or_id, id, arg_types) if @functions.key?(id)

          candidates = @alias_overloads[id]
          raise ResolutionError, "unknown function #{alias_or_id}" if candidates.nil?

          return resolve_single(alias_or_id, candidates.first, arg_types) if candidates.size == 1

          resolve_overloaded(alias_or_id, candidates, arg_types)
        end

        def function(id)
          @functions.fetch(id) { raise ResolutionError, "unknown function #{id}" }
        end

        def exists?(id)
          @functions.key?(id.to_s)
        end

        private

        # A single concrete overload: arity must match, and every constrained
        # parameter must accept its argument. On failure the message points at
        # the specific argument(s).
        def resolve_single(alias_or_id, fn_id, arg_types)
          fn = @functions[fn_id]
          validate_arity!(alias_or_id, fn, arg_types)
          return fn_id if params_match?(fn.params, arg_types)

          raise ResolutionError, mismatch_message(alias_or_id, fn.params, arg_types)
        end

        # Several overloads share the alias: rank by match score and pick the
        # best. If none match, report the most precise failure — an arity error
        # when no overload even accepts this argument count, otherwise a
        # type-mismatch against the closest-arity overload.
        def resolve_overloaded(alias_or_id, candidates, arg_types)
          scored = candidates.map { |fn_id| [fn_id, total_score(@functions[fn_id].params, arg_types)] }
          best_id, best_score = scored.max_by { |_, score| score }
          return best_id if best_score.positive?

          arities = candidates.map { |fn_id| @functions[fn_id].params.size }.uniq
          unless arities.include?(arg_types.size)
            expected = arities.sort.join(" or ")
            raise ResolutionError, "#{alias_or_id} expects #{expected} argument(s), got #{arg_types.size}"
          end

          closest = candidates.min_by { |fn_id| (@functions[fn_id].params.size - arg_types.size).abs }
          raise ResolutionError, mismatch_message(alias_or_id, @functions[closest].params, arg_types)
        end

        def params_match?(params, arg_types)
          return false if params.size != arg_types.size

          params.zip(arg_types).all? { |param, type| @types.compatible?(param["dtype"], type) }
        end

        # Total match quality across all params; 0 if arity or any constraint
        # fails. Higher means more exact-constraint matches, so exact overloads
        # win over permissive ones.
        def total_score(params, arg_types)
          return 0 if params.size != arg_types.size

          scores = params.zip(arg_types).map { |param, type| @types.match_score(param["dtype"], type) }
          return 0 if scores.any?(&:zero?)

          scores.sum
        end

        def validate_arity!(alias_or_id, function, arg_types)
          return if function.params.size == arg_types.size

          raise ResolutionError,
                "#{alias_or_id} expects #{function.params.size} argument(s), got #{arg_types.size}"
        end

        # Point the user at exactly which argument is wrong and what was expected.
        def mismatch_message(alias_or_id, params, arg_types)
          offending = params.zip(arg_types).filter_map.with_index do |(param, type), i|
            next if @types.compatible?(param["dtype"], type)

            expected = param["dtype"] || "any"
            "argument #{i + 1} (#{param['name']}) expected #{expected}, got #{type}"
          end

          detail = offending.empty? ? "" : ": #{offending.join('; ')}"
          "#{alias_or_id}(#{format_types(arg_types)}) - type mismatch#{detail}"
        end

        def build_alias_overloads(functions)
          functions.values.each_with_object({}) do |func, acc|
            func.aliases.each do |name|
              (acc[name] ||= []) << func.id
            end
          end
        end

        def format_types(arg_types)
          arg_types.map(&:to_s).join(", ")
        end

        class ResolutionError < StandardError; end
      end
    end
  end
end
