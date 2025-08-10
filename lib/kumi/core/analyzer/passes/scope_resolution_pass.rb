# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Plans per-declaration execution scope and join/lift needs.
        # Determines the dimensional scope (array nesting level) for each declaration
        # based on vectorization metadata and input paths.
        #
        # DEPENDENCIES: :declarations, :input_metadata, :broadcasts
        # PRODUCES: :scope_plans, :decl_shapes
        class ScopeResolutionPass < PassBase
          include Kumi::Core::Analyzer::Plans

          def run(_errors)
            declarations = get_state(:declarations, required: true)
            input_metadata = get_state(:input_metadata, required: true)
            broadcasts = get_state(:broadcasts) || {}

            scope_plans = {}
            decl_shapes = {}

            declarations.each do |name, decl|
              debug_output(name, decl) if ENV["DEBUG_SCOPE_RESOLUTION"]

              target_scope = infer_target_scope(name, decl, broadcasts, input_metadata)
              result_kind = determine_result_kind(name, target_scope, broadcasts)

              plan = build_scope_plan(target_scope)
              scope_plans[name] = plan
              decl_shapes[name] = { scope: target_scope, result: result_kind }.freeze

              debug_result(target_scope, result_kind) if ENV["DEBUG_SCOPE_RESOLUTION"]
            end

            # Return new state with scope information
            state.with(:scope_plans, scope_plans.freeze)
                 .with(:decl_shapes, decl_shapes.freeze)
          end

          private

          def debug_output(name, decl)
            puts "\n=== Resolving scope for #{name} ==="
            puts "Declaration: #{decl.inspect}"
          end

          def debug_result(target_scope, result_kind)
            puts "Target scope: #{target_scope.inspect}"
            puts "Result kind: #{result_kind.inspect}"
          end

          def build_scope_plan(target_scope)
            Scope.new(
              scope: target_scope,
              lifts: [], # Will be computed during IR lowering per call-site
              join_hint: nil, # Will be set to :zip when multiple vectorized args exist
              arg_shapes: {} # Optional: filled during lowering
            )
          end

          def determine_result_kind(name, target_scope, broadcasts)
            return :scalar if broadcasts.dig(:reduction_operations, name)
            return :scalar if target_scope.empty?

            { array: :dense }
          end

          # Derive scope from vectorization metadata or from deepest input path
          def infer_target_scope(name, decl, broadcasts, input_metadata)
            vec = broadcasts.dig(:vectorized_operations, name)
            return [] unless vec

            puts "Vectorization info: #{vec.inspect}" if ENV["DEBUG_SCOPE_RESOLUTION"]

            case vec[:source]
            when :nested_array_access, :array_field_access
              path = vec[:path] || []
              dims_from_path(path, input_metadata)
            when :cascade_with_vectorized_conditions_or_results,
                 :cascade_condition_with_vectorized_trait
              # Fallback: derive from first input path seen in expression
              path = find_first_input_path(decl.expression) || []
              dims_from_path(path, input_metadata)
            else
              []
            end
          end

          def find_first_input_path(expr)
            return nil unless expr

            # Handle InputElementReference directly
            return expr.path if expr.is_a?(Kumi::Syntax::InputElementReference)

            # Handle InputReference (convert to path array)
            return [expr.name] if expr.is_a?(Kumi::Syntax::InputReference)

            # Recursively search in CallExpression arguments
            if expr.is_a?(Kumi::Syntax::CallExpression) && expr.args
              expr.args.each do |arg|
                path = find_first_input_path(arg)
                return path if path
              end
            end

            # Search in CascadeExpression cases
            if expr.is_a?(Kumi::Syntax::CascadeExpression) && expr.cases
              expr.cases.each do |case_item|
                path = find_first_input_path(case_item.condition)
                return path if path

                path = find_first_input_path(case_item.result)
                return path if path
              end
            end

            # Search in expression field if present
            return find_first_input_path(expr.expression) if expr.respond_to?(:expression)

            nil
          end

          # Map an input path like [:regions, :offices, :salary] to container dims [:regions, :offices]
          def dims_from_path(path, input_metadata)
            dims = []
            meta = input_metadata

            path.each do |seg|
              field = meta[seg] || meta[seg.to_sym] || meta[seg.to_s]
              break unless field

              dims << seg.to_sym if field[:type] == :array

              meta = field[:children] || {}
            end

            dims
          end
        end
      end
    end
  end
end
