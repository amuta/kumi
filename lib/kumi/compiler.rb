# frozen_string_literal: true

module Kumi
  # Compiles an analyzed schema into executable lambdas
  class Compiler
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

        lambda do |ctx|
          # Start with the top-level collection from the context.
          collection = ctx[path.first]

          # Recursively map over the nested collections.
          # The `dig_and_map` helper will handle any level of nesting.
          dig_and_map(collection, path[1..])
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
        
        # Check if this is a vectorized operation
        if vectorized_operation?(expr)
          ->(ctx) { invoke_vectorized_function(fn_name, arg_fns, ctx, expr.loc) }
        else
          ->(ctx) { invoke_function(fn_name, arg_fns, ctx, expr.loc) }
        end
      end

      def compile_cascade(expr)
        # Check if current declaration is vectorized
        broadcast_meta = @analysis.state[:broadcast_metadata]
        is_vectorized = @current_declaration && broadcast_meta&.dig(:vectorized_operations, @current_declaration)
        
        
        # For vectorized cascades, we need to transform conditions that use all?
        if is_vectorized
          pairs = expr.cases.map do |c|
            condition_fn = transform_vectorized_condition(c.condition)
            result_fn = compile_expr(c.result)
            [condition_fn, result_fn]
          end
        else
          pairs = expr.cases.map { |c| [compile_expr(c.condition), compile_expr(c.result)] }
        end
        
        if is_vectorized
          lambda do |ctx|
            # This cascade can be vectorized - check if we actually need to at runtime
            # Evaluate all conditions and results to check for arrays
            cond_results = pairs.map { |cond, _res| cond.call(ctx) }
            res_results = pairs.map { |_cond, res| res.call(ctx) }
            
            # Check if any conditions or results are arrays (vectorized)
            has_vectorized_data = (cond_results + res_results).any? { |v| v.is_a?(Array) }
            
            if has_vectorized_data
              # Apply element-wise cascade evaluation
              array_length = cond_results.find { |v| v.is_a?(Array) }&.length || 
                           res_results.find { |v| v.is_a?(Array) }&.length || 1
              
              (0...array_length).map do |i|
                pairs.each_with_index do |(cond, res), pair_idx|
                  cond_val = cond_results[pair_idx].is_a?(Array) ? cond_results[pair_idx][i] : cond_results[pair_idx]
                  
                  if cond_val
                    res_val = res_results[pair_idx].is_a?(Array) ? res_results[pair_idx][i] : res_results[pair_idx]
                    break res_val
                  end
                end || nil
              end
            else
              # All data is scalar - use regular cascade evaluation
              pairs.each_with_index do |(cond, res), pair_idx|
                return res_results[pair_idx] if cond_results[pair_idx]
              end
              nil
            end
          end
        else
          lambda do |ctx|
            pairs.each { |cond, res| return res.call(ctx) if cond.call(ctx) }
            nil
          end
        end
      end

      def transform_vectorized_condition(condition_expr)
        # If this is fn(:all?, [trait_ref]), extract the trait_ref for vectorized cascades
        if condition_expr.is_a?(Kumi::Syntax::CallExpression) && 
           condition_expr.fn_name == :all? && 
           condition_expr.args.length == 1
          
          arg = condition_expr.args.first
          if arg.is_a?(Kumi::Syntax::ArrayExpression) && arg.elements.length == 1
            trait_ref = arg.elements.first
            return compile_expr(trait_ref)
          end
        end
        
        # Otherwise compile normally
        compile_expr(condition_expr)
      end
    end

    include ExprCompilers

    # Map node classes to compiler methods
    DISPATCH = {
      Kumi::Syntax::Literal => :compile_literal,
      Kumi::Syntax::InputReference => :compile_field_node,
      Kumi::Syntax::InputElementReference => :compile_element_field_reference,
      Kumi::Syntax::DeclarationReference => :compile_binding_node,
      Kumi::Syntax::ArrayExpression => :compile_list,
      Kumi::Syntax::CallExpression => :compile_call,
      Kumi::Syntax::CascadeExpression => :compile_cascade
    }.freeze

    def self.compile(schema, analyzer:)
      new(schema, analyzer).compile
    end

    def initialize(schema, analyzer)
      @schema = schema
      @analysis = analyzer
      @bindings = {}
    end

    def compile
      build_index
      @analysis.topo_order.each do |name|
        decl = @index[name] or raise("Unknown binding #{name}")
        compile_declaration(decl)
      end

      CompiledSchema.new(@bindings.freeze)
    end

    private

    def build_index
      @index = {}
      @schema.attributes.each { |a| @index[a.name] = a }
      @schema.traits.each     { |t| @index[t.name] = t }
    end

    def dig_and_map(collection, path_segments)
      return collection unless collection.is_a?(Array)

      current_segment = path_segments.first
      remaining_segments = path_segments[1..]

      collection.map do |element|
        value = element[current_segment]

        # If there are more segments, recurse. Otherwise, return the value.
        if remaining_segments.empty?
          value
        else
          dig_and_map(value, remaining_segments)
        end
      end
    end

    def compile_declaration(decl)
      @current_declaration = decl.name
      kind = decl.is_a?(Kumi::Syntax::TraitDeclaration) ? :trait : :attr
      fn = compile_expr(decl.expression)
      @bindings[decl.name] = [kind, fn]
      @current_declaration = nil
    end

    # Dispatch to the appropriate compile_* method
    def compile_expr(expr)
      method = DISPATCH.fetch(expr.class)
      send(method, expr)
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

    def vectorized_operation?(expr)
      # Check if this operation uses vectorized inputs
      broadcast_meta = @analysis.state[:broadcast_metadata]
      return false unless broadcast_meta
      
      # Reduction functions are NOT vectorized operations - they consume arrays
      if FunctionRegistry.reducer?(expr.fn_name)
        return false
      end
      
      expr.args.any? do |arg|
        case arg
        when Kumi::Syntax::InputElementReference
          broadcast_meta[:array_fields]&.key?(arg.path.first)
        when Kumi::Syntax::DeclarationReference
          broadcast_meta[:vectorized_operations]&.key?(arg.name)
        else
          false
        end
      end
    end
    
    
    def invoke_vectorized_function(name, arg_fns, ctx, loc)
      # Evaluate arguments
      values = arg_fns.map { |fn| fn.call(ctx) }
      
      # Check if any argument is vectorized (array)
      has_vectorized_args = values.any? { |v| v.is_a?(Array) }
      
      if has_vectorized_args
        # Apply function with broadcasting to all vectorized arguments
        vectorized_function_call(name, values)
      else
        # All arguments are scalars - regular function call
        fn = FunctionRegistry.fetch(name)
        fn.call(*values)
      end
    rescue StandardError => e
      enhanced_message = "Error calling fn(:#{name}) at #{loc}: #{e.message}"
      runtime_error = Errors::RuntimeError.new(enhanced_message)
      runtime_error.set_backtrace(e.backtrace)
      runtime_error.define_singleton_method(:cause) { e }
      raise runtime_error
    end
    
    def vectorized_function_call(fn_name, values)
      # Get the function from registry
      fn = FunctionRegistry.fetch(fn_name)
      
      # Find array dimensions for broadcasting
      array_values = values.select { |v| v.is_a?(Array) }
      return fn.call(*values) if array_values.empty?
      
      # All arrays should have the same length (validation could be added)
      array_length = array_values.first.size
      
      # Broadcast and apply function element-wise
      (0...array_length).map do |i|
        element_args = values.map do |v|
          v.is_a?(Array) ? v[i] : v  # Broadcast scalars
        end
        fn.call(*element_args)
      end
    end
    

    def invoke_function(name, arg_fns, ctx, loc)
      fn = FunctionRegistry.fetch(name)
      values = arg_fns.map { |fn| fn.call(ctx) }
      fn.call(*values)
    rescue StandardError => e
      # Preserve original error class and backtrace while adding context
      enhanced_message = "Error calling fn(:#{name}) at #{loc}: #{e.message}"

      if e.is_a?(Kumi::Errors::Error)
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
  end
end
