# frozen_string_literal: true

module Kumi
  module Core
    # Clean compiler that uses broadcast detector metadata for pure translation
    class RubyCompiler
      def initialize(schema, analysis_result)
        @schema = schema
        @analysis = analysis_result
        @metadata = analysis_result.state[:detector_metadata] || {}
        @bindings = {}
        @index = {}
        @accessors = {}
      end

      def compile
        build_index
        build_accessors # Build smart accessor procs

        # Compile in dependency order
        @analysis.topo_order.each do |name|
          decl = @index[name] or raise("Unknown binding #{name}")
          @bindings[name] = compile_declaration(name, decl)
        end

        Core::CompiledSchema.new(@bindings.freeze)
      end

      private

      def build_index
        (@schema.attributes + @schema.traits).each { |decl| @index[decl.name] = decl }
      end

      def build_accessors
        input_metadata = @analysis.state[:inputs] || {}
        access_plans = Core::Compiler::AccessorPlanner.plan(input_metadata)
        @accessors = Core::Compiler::AccessorBuilder.build(access_plans)

        puts "DEBUG: Built accessors: #{@accessors.keys}" if ENV["DEBUG_COMPILER"]
      end

      def compile_declaration(name, declaration)
        metadata = @metadata[name]

        puts "DEBUG: Compiling #{name}" if ENV["DEBUG_COMPILER"]
        puts "DEBUG: Metadata: #{metadata.inspect}" if ENV["DEBUG_COMPILER"]

        case metadata&.[](:operation_type)
        when :vectorized
          compile_vectorized_operation(declaration.expression, metadata)
        when :reduction
          compile_reduction_operation(declaration.expression, metadata)
        when :array_reference
          compile_array_reference(declaration.expression, metadata)
        when :scalar
          compile_scalar_expression(declaration.expression)
        else
          # Fallback for declarations without metadata (shouldn't happen)
          compile_scalar_expression(declaration.expression)
        end
      end

      def compile_vectorized_operation(expr, metadata)
        strategy = metadata[:strategy]
        operands = metadata[:operands] || []

        # Pre-resolve all operands using OperandResolver for pure lambda generation
        operand_resolver = Core::Compiler::OperandResolver.new(@bindings, @accessors)
        
        # Pre-resolve the operation function and registry function
        operation_fn = Kumi::Registry.fetch(expr.fn_name)
        registry_fn = Kumi::Registry.fetch(strategy)

        # Pre-resolve all operands into pure extractors
        resolved_extractors = operands.map do |operand|
          if operand[:source][:kind] == :unknown || operand[:source][:kind] == :nested_call
            # Fallback for complex operands - let accessor system handle them
            lambda { |ctx| extract_operand_fallback(ctx, operand) }
          else
            operand_resolver.resolve_operand(operand)
          end
        end

        # Pre-determine argument structure at compile time based on strategy
        arg_builder = build_strategy_arg_builder(strategy, operation_fn, resolved_extractors)

        # Generate pure lambda with pre-resolved argument builder
        lambda do |ctx|
          arg_builder.call(ctx)
        end
      end

      def compile_reduction_operation(_expr, metadata)
        puts "DEBUG: Reduction metadata for #{metadata[:function]}: #{metadata.inspect}" if ENV["DEBUG_COMPILER"]

        # Pre-resolve the operand using OperandResolver for pure lambda generation
        operand_with_flattening = metadata[:input_source].dup
        operand_with_flattening[:requires_flattening] = metadata[:requires_flattening]
        
        # Try to pre-resolve the operand using OperandResolver
        operand_resolver = Core::Compiler::OperandResolver.new(@bindings, @accessors)
        
        # Check if this is a resolvable operand or if we need to fall back to runtime
        if operand_with_flattening[:source][:kind] == :unknown || operand_with_flattening[:source][:kind] == :nested_call
          # Fallback: pre-resolve function, use runtime for complex operand extraction
          reduce_fn = Kumi::Registry.fetch(metadata[:function])
          
          return lambda do |ctx|
            # Extract input data using the existing runtime extraction method
            input_data = extract_reduction_input(ctx, operand_with_flattening)
            reduce_fn.call(input_data)
          end
        end
        
        resolved_extractor = operand_resolver.resolve_operand(operand_with_flattening)
        
        # Add flattening wrapper if needed
        if metadata[:requires_flattening]
          final_extractor = lambda { |ctx| resolved_extractor.call(ctx).flatten }
        else
          final_extractor = resolved_extractor
        end

        # Get the reduction function at compile time
        reduce_fn = Kumi::Registry.fetch(metadata[:function])

        # Generate pure lambda with no runtime logic
        lambda do |ctx|
          input_data = final_extractor.call(ctx)
          result = reduce_fn.call(input_data)
          
          puts "DEBUG: Reduction result: #{result.inspect}" if ENV["DEBUG_COMPILER"]
          result
        end
      end

      def compile_array_reference(_expr, metadata)
        array_source = metadata[:array_source]

        lambda do |ctx|
          # Array references should use element accessors for field extraction
          raise "Array reference without path: #{array_source}" unless array_source[:path]

          path_key = array_source[:path].join(".")
          element_accessor_key = "#{path_key}:element"

          unless @accessors.key?(element_accessor_key)
            raise "Missing accessor for #{path_key}:element - accessor system should have created this"
          end

          @accessors[element_accessor_key].call(ctx)
        end
      end

      def compile_scalar_expression(expr)
        expression_builder.compile(expr)
      end

      def expression_builder
        @expression_builder ||= Core::Compiler::ExpressionBuilder.new(@bindings)
      end

      # Fallback runtime extraction for complex operands that can't be pre-resolved
      def extract_reduction_input(ctx, operand)
        extract_operand_fallback(ctx, operand, flattening: operand[:requires_flattening])
      end

      def extract_operand_fallback(ctx, operand, flattening: false)
        source = operand[:source]
        
        input_data = case source[:kind]
                     when :declaration
                       binding = @bindings[source[:name]]
                       binding&.call(ctx)
                     when :input_element
                       path = source[:path]
                       path_key = path.join(".")
                       
                       # Use flattened accessor if flattening is required
                       accessor_type = flattening ? "flattened" : "element"
                       accessor_key = "#{path_key}:#{accessor_type}"
                       
                       puts "DEBUG: extract_operand_fallback - path: #{path_key}, flattening: #{flattening}, accessor_key: #{accessor_key}" if ENV["DEBUG_COMPILER"]
                       
                       result = @accessors[accessor_key]&.call(ctx)
                       puts "DEBUG: extract_operand_fallback - result: #{result.inspect}" if ENV["DEBUG_COMPILER"]
                       result
                     when :input_field
                       field_name = source[:name]
                       ctx[field_name.to_s] || ctx[field_name.to_sym]
                     when :literal
                       source[:value]
                     when :nested_call
                       # Simple nested call handling - compile the nested operation and execute it
                       nested_metadata = source[:metadata]
                       compile_nested_operation(nested_metadata, ctx)
                     else
                       raise "Unknown operand source: #{source[:kind]}"
                     end
        
        # Apply flattening if needed
        if flattening
          input_data.flatten
        else
          input_data
        end
      end

      # Pre-build argument structure at compile time based on strategy
      # Returns a lambda that builds arguments when called with context
      def build_strategy_arg_builder(strategy, operation_fn, resolved_extractors)
        # Pre-resolve the registry function at compile time
        registry_fn = Kumi::Registry.fetch(strategy)
        
        case strategy
        when :array_scalar_object, :array_scalar_vector
          # Pre-resolved structure: [operation_proc, array_values, scalar_value]
          array_extractor = resolved_extractors[0]
          scalar_extractor = resolved_extractors[1]
          
          lambda do |ctx|
            array_values = array_extractor.call(ctx)
            scalar_value = scalar_extractor.call(ctx)
            registry_fn.call(operation_fn, array_values, scalar_value)
          end
          
        when :element_wise_object, :element_wise_vector
          # Pre-resolved structure: [operation_proc, array_values1, array_values2]
          array1_extractor = resolved_extractors[0]
          array2_extractor = resolved_extractors[1]
          
          lambda do |ctx|
            array1_values = array1_extractor.call(ctx)
            array2_values = array2_extractor.call(ctx)
            registry_fn.call(operation_fn, array1_values, array2_values)
          end
          
        when :parent_child_vector
          # Pre-resolved structure: [operation_proc, nested_array, parent_array]
          nested_extractor = resolved_extractors[0]
          parent_extractor = resolved_extractors[1]
          
          lambda do |ctx|
            nested_array = nested_extractor.call(ctx)
            parent_array = parent_extractor.call(ctx)
            registry_fn.call(operation_fn, nested_array, parent_array)
          end
          
        when :parent_child_object
          # More complex case - needs metadata for field extraction
          # For now, delegate to fallback for this complex strategy
          lambda do |ctx|
            # Use the fallback runtime extraction for parent_child_object
            # This strategy needs special field name handling
            operand_values = resolved_extractors.map { |extractor| extractor.call(ctx) }
            
            # parent_child_object needs: [operation_proc, parent_array, child_field, child_value_field, parent_value_field]
            # This requires metadata that we don't have in the current structure
            raise "parent_child_object strategy needs metadata-driven implementation"
          end
          
        else
          raise "Unknown strategy: #{strategy}"
        end
      end

      # Compile nested operation - just execute the inner operation and return its result
      def compile_nested_operation(metadata, ctx)
        case metadata[:operation_type]
        when :reduction
          # Function composition: compile inner operation and apply outer function
          reduce_fn = Kumi::Registry.fetch(metadata[:function])
          input_operand = metadata[:input_source]
          
          # Recursively extract the input (which may itself be nested)
          input_data = extract_operand_fallback(ctx, input_operand, flattening: metadata[:requires_flattening])
          
          # Apply the function to the composed result
          reduce_fn.call(input_data)
        else
          raise "Nested operation type #{metadata[:operation_type]} not supported yet"
        end
      end

    end
  end
end
