# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LowerToIR
          module Access
            # Decide the concrete accessor plan for a given input node.
            # Prefers node_index annotation (:access_mode), then conservative fallback.
            def access_mode_for_input(node, access_plans, node_index, need_indices: false)
              key = case node
                    when Syntax::InputReference         then node.name.to_s
                    when Syntax::InputElementReference  then node.path.join(".")
                    else 
                      @errors << Core::ErrorReporter.create_error(
                        "not an input node: #{node.class}",
                        location: node.respond_to?(:loc) ? node.loc : nil,
                        type: :developer
                      )
                      return [nil, [], true, false]
                    end

              plans = access_plans[key]
              unless plans
                @errors << Core::ErrorReporter.create_error(
                  "No access plan for #{key}",
                  location: node.respond_to?(:loc) ? node.loc : nil,
                  type: :developer
                )
                return [nil, [], true, false]
              end

              annotated_mode = (node_index[node.object_id] || {})[:access_mode]
              mode = annotated_mode || (need_indices ? :each_indexed : :read)
              # Fallbacks
              candidate = plans.find { |p| p.mode == mode } ||
                          plans.find { |p| p.mode == :ravel } ||
                          plans.first

              scope    = candidate ? Array(candidate.scope) : []
              is_scalar = candidate && %i[read materialize].include?(candidate.mode)
              has_idx   = candidate && candidate.mode == :each_indexed
              [candidate&.accessor_key, scope, is_scalar, has_idx]
            end
          end
        end
      end
    end
  end
end