# frozen_string_literal: true

module Kumi
  # Compiles an analyzed schema into executable lambdas
  class Compiler < Core::CompilerBase
    # ExprCompilers holds per-node compile implementations
    module ExprCompilers
      def compile_literal(expr)
        v = expr.value
        ->(_ctx) { v }
      end

      def compile_field_node(expr)
        compile_field(expr)
      end

      def compile_element_field_reference(expr)
        path = expr.path

        # Check if we have nested paths metadata for this path
        nested_paths = @analysis.state[:broadcasts]&.dig(:nested_paths)
        if nested_paths && nested_paths[path]
          # Determine operation mode based on context
          operation_mode = determine_operation_mode_for_path(path)
          lambda do |ctx|
            traverse_nested_path(ctx, path, operation_mode)
          end
        else
          # ERROR: All nested paths should have metadata from the analyzer
          # If we reach here, it means the BroadcastDetector didn't process this path
          raise Errors::CompilationError.new(
            "Missing nested path metadata for #{path.inspect}. This indicates an analyzer bug."
          )
        end
      end

      def compile_binding_node(expr)
        name = expr.name
        # Handle forward references in cycles by deferring binding lookup to runtime
        lambda do |ctx|
          fn = @bindings[name].last
          fn.call(ctx)
        end
      end

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
          cascade_info = compilation_meta&.dig(:cascade_info) || {}

          # Build executor at COMPILATION time (outside the lambda)
          strategy = @analysis.state[:broadcasts][:cascade_strategies][current_decl_name]
          executor = strategy ? Core::CascadeExecutorBuilder.build_executor(strategy, @analysis.state) : nil

          # Metadata-driven vectorized cascade evaluation
          lambda do |ctx|
            # Evaluate all conditions and results
            cond_results = pairs.map { |cond, _res| cond.call(ctx) }
            res_results = pairs.map { |_cond, res| res.call(ctx) }
            base_result = base_fn ? base_fn.call(ctx) : nil

            if ENV["DEBUG_CASCADE"]
              puts "DEBUG: Vectorized cascade evaluation for #{current_decl_name}:"
              cond_results.each_with_index { |cr, i| puts "  cond_results[#{i}]: #{cr.inspect}" }
              res_results.each_with_index { |rr, i| puts "  res_results[#{i}]: #{rr.inspect}" }
              puts "  base_result: #{base_result.inspect}"
              puts "  Pre-computed cascade_info: #{cascade_info.inspect}"
            end

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
            base_fn ? base_fn.call(ctx) : nil
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

          if ENV["DEBUG_CASCADE"]
            puts "      cascade_and hierarchical broadcasting:"
            trait_values.each_with_index { |tv, i| puts "        trait[#{i}]: #{tv.inspect}" }
          end

          # Use the cascade_and function directly on the array structures
          # This will handle hierarchical broadcasting through element_wise_and
          fn = Kumi::Registry.fetch(:cascade_and)
          result = fn.call(*trait_values)

          puts "        hierarchical cascade_and result: #{result.inspect}" if ENV["DEBUG_CASCADE"]

          result
        end
      end

    end

    include ExprCompilers

    def self.compile(schema, analyzer:)
      new(schema, analyzer).compile
    end

    def initialize(schema, analyzer)
      super
      @bindings = {}
    end

    def compile
      build_index
      @analysis.topo_order.each do |name|
        decl = @index[name] or raise("Unknown binding #{name}")
        compile_declaration(decl)
      end

      Core::CompiledSchema.new(@bindings.freeze)
    end

    private

    # Metadata-driven nested array traversal using the traversal algorithm from our design
    def traverse_nested_path(data, path, operation_mode)
      result = traverse_path_recursive(data, path, operation_mode)

      # Post-process result based on operation mode
      case operation_mode
      when :flatten
        # Completely flatten nested arrays for aggregation
        flatten_completely(result)
      else
        result
      end
    end

    def traverse_path_recursive(data, path, operation_mode)
      return data if path.empty?

      field = path.first
      remaining_path = path[1..]

      if remaining_path.empty?
        # Final field - extract based on operation mode
        case operation_mode
        when :broadcast, :flatten
          # Extract field preserving array structure
          extract_field_preserving_structure(data, field)
        else
          # Simple field access
          data.is_a?(Array) ? data.map { |item| item[field] } : data[field]
        end
      elsif data.is_a?(Array)
        # Intermediate step - traverse deeper
        # Array of items - traverse each item
        data.map { |item| traverse_path_recursive(item[field], remaining_path, operation_mode) }
      else
        # Single item - traverse directly
        traverse_path_recursive(data[field], remaining_path, operation_mode)
      end
    end

    def extract_field_preserving_structure(data, field)
      if data.is_a?(Array)
        data.map { |item| extract_field_preserving_structure(item, field) }
      else
        data[field]
      end
    end

    def flatten_completely(data)
      result = []
      flatten_recursive(data, result)
      result
    end

    def flatten_recursive(data, result)
      if data.is_a?(Array)
        data.each { |item| flatten_recursive(item, result) }
      else
        result << data
      end
    end

    def compile_declaration(decl)
      @current_declaration = decl.name
      kind = decl.is_a?(Kumi::Syntax::TraitDeclaration) ? :trait : :attr
      fn = compile_expr(decl.expression)
      @bindings[decl.name] = [kind, fn]
      @current_declaration = nil
    end

    def compile_field(node)
      name = node.name
      loc  = node.loc
      lambda do |ctx|
        return ctx[name] if ctx.respond_to?(:key?) && ctx.key?(name)

        raise Errors::RuntimeError,
              "Key '#{name}' not found at #{loc}. Available: #{ctx.respond_to?(:keys) ? ctx.keys.join(', ') : 'N/A'}"
      end
    end

    def invoke_function(name, arg_fns, ctx, loc)
      fn = Kumi::Registry.fetch(name)
      values = arg_fns.map { |fn| fn.call(ctx) }

      # REMOVED AUTO-FLATTENING: Let operations work on the structure they receive
      # If flattening is needed, it should be handled by explicit operation modes
      # in the InputElementReference compilation, not here.
      fn.call(*values)
    rescue StandardError => e
      # Preserve original error class and backtrace while adding context
      enhanced_message = "Error calling fn(:#{name}) at #{loc}: #{e.message}"

      if e.is_a?(Kumi::Core::Errors::Error)
        # Re-raise Kumi errors with enhanced message but preserve type
        e.define_singleton_method(:message) { enhanced_message }
        raise e
      else
        # For non-Kumi errors, wrap in RuntimeError but preserve original error info
        runtime_error = Errors::RuntimeError.new(enhanced_message)
        runtime_error.set_backtrace(e.backtrace)
        runtime_error.define_singleton_method(:cause) { e }
        raise runtime_error
      end
    end

    def invoke_function_with_flattening(name, arg_fns, ctx, loc, _original_args, _flattening_info)
      fn = Kumi::Registry.fetch(name)

      # Use pre-computed flattening indices from analysis
      compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)
      flatten_indices = compilation_meta&.dig(:function_call_strategy, :flatten_argument_indices) || []

      values = arg_fns.map.with_index do |arg_fn, index|
        value = arg_fn.call(ctx)
        flatten_indices.include?(index) ? flatten_completely(value) : value
      end

      fn.call(*values)
    rescue StandardError => e
      enhanced_message = "Error calling fn(:#{name}) at #{loc}: #{e.message}"
      runtime_error = Errors::RuntimeError.new(enhanced_message)
      runtime_error.set_backtrace(e.backtrace)
      runtime_error.define_singleton_method(:cause) { e }
      raise runtime_error
    end
  end
end
