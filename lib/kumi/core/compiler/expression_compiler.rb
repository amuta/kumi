# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module ExpressionCompiler
        private

        def compile_list(expr)
          fns = expr.elements.map { |e| compile_expr(e) }
          ->(ctx) { fns.map { |fn| fn.call(ctx) } }
        end

        def compile_call(expr)
          fn_name = expr.fn_name
          arg_fns = expr.args.map { |a| compile_expr(a) }

          # Get compilation metadata once
          compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)

          # Check if this is a vectorized operation
          if vectorized_operation?(expr)
            # Build vectorized executor at COMPILATION time
            executor = Core::VectorizedFunctionBuilder.build_executor(fn_name, compilation_meta, @analysis.state)

            lambda do |ctx|
              # Evaluate arguments and use pre-built executor at RUNTIME
              values = arg_fns.map { |fn| fn.call(ctx) }
              executor.call(values, expr.loc)
            end
          else
            # Use pre-computed function call strategy
            function_strategy = compilation_meta&.dig(:function_call_strategy) || {}

            if function_strategy[:flattening_required]
              flattening_info = @analysis.state[:broadcasts][:flattening_declarations][@current_declaration]
              ->(ctx) { invoke_function_with_flattening(fn_name, arg_fns, ctx, expr.loc, expr.args, flattening_info) }
            else
              ->(ctx) { invoke_function(fn_name, arg_fns, ctx, expr.loc) }
            end
          end
        end

        def compile_cascade(expr)
          # Use metadata to determine if this cascade is vectorized
          broadcast_meta = @analysis.state[:broadcasts]
          cascade_info = @current_declaration && broadcast_meta&.dig(:vectorized_operations, @current_declaration)
          is_vectorized = cascade_info && cascade_info[:source] == :cascade_with_vectorized_conditions_or_results

          # Separate conditional cases from base case
          conditional_cases = expr.cases.select(&:condition)
          base_case = expr.cases.find { |c| c.condition.nil? }

          # Compile conditional pairs
          pairs = conditional_cases.map do |c|
            condition_fn = if is_vectorized
                             transform_vectorized_condition(c.condition)
                           else
                             compile_expr(c.condition)
                           end
            result_fn = compile_expr(c.result)
            [condition_fn, result_fn]
          end

          # Compile base case
          base_fn = base_case ? compile_expr(base_case.result) : nil

          if is_vectorized
            # Capture the current declaration name in the closure
            current_decl_name = @current_declaration

            # Get pre-computed cascade strategy
            compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, current_decl_name)
            compilation_meta&.dig(:cascade_info) || {}

            # Build executor at COMPILATION time (outside the lambda)
            strategy = @analysis.state[:broadcasts][:cascade_strategies][current_decl_name]
            executor = strategy ? Core::CascadeExecutorBuilder.build_executor(strategy, @analysis.state) : nil

            # Metadata-driven vectorized cascade evaluation
            lambda do |ctx|
              # Evaluate all conditions and results
              cond_results = pairs.map { |cond, _res| cond.call(ctx) }
              res_results = pairs.map { |_cond, res| res.call(ctx) }
              base_result = base_fn&.call(ctx)

              # Use pre-built executor at RUNTIME
              if executor
                executor.call(cond_results, res_results, base_result, pairs)
              else
                # Fallback for cases without strategy
                pairs.each_with_index do |(_cond, _res), pair_idx|
                  return res_results[pair_idx] if cond_results[pair_idx]
                end
                base_result
              end
            end
          else
            # Non-vectorized cascade - standard evaluation
            lambda do |ctx|
              pairs.each { |cond, res| return res.call(ctx) if cond.call(ctx) }
              # If no conditional case matched, return base case
              base_fn&.call(ctx)
            end
          end
        end

        def transform_vectorized_condition(condition_expr)
          if condition_expr.is_a?(Kumi::Syntax::CallExpression) &&
             condition_expr.fn_name == :cascade_and

            puts "    transform_vectorized_condition: handling cascade_and with #{condition_expr.args.length} args" if ENV["DEBUG_CASCADE"]

            # For cascade_and in vectorized contexts, we need to compile it as a structure-level operation
            # rather than element-wise operation
            return compile_cascade_and_for_hierarchical_broadcasting(condition_expr)
          end

          # Otherwise compile normally
          compile_expr(condition_expr)
        end

        def compile_cascade_and_for_hierarchical_broadcasting(condition_expr)
          # Compile individual trait references
          trait_fns = condition_expr.args.map { |arg| compile_expr(arg) }

          lambda do |ctx|
            # Evaluate all traits to get their array structures
            trait_values = trait_fns.map { |fn| fn.call(ctx) }

            fn = Kumi::Registry.fetch(:cascade_and)
            result = fn.call(*trait_values)

            result
          end
        end
      end
    end
  end
end
