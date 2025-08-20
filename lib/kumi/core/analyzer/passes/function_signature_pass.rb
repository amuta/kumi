# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Apply NEP-20 signature resolution to function calls and populate type information
        # DEPENDENCIES: :node_index from Toposorter, :input_metadata, :inferred_types, :decl_shapes (preferred), :broadcasts (optional)
        #
        # PRODUCES:
        #   - Signature metadata in node_index for CallExpression nodes
        #   - :inferred_type in node_index for InputElementReference nodes (direct object_id-based storage)
        #   - :result_dtype (optional, if function declares dtype computation rules)
        #
        # RELATIONSHIP WITH TypeCheckerV2:
        #   - This pass may pre-compute result_dtype, TypeCheckerV2 computes if missing
        #   - TypeCheckerV2 uses the signature metadata for constraint validation
        #   - Both passes use the same RegistryV2 function resolution
        #
        # TYPE STORAGE ARCHITECTURE:
        #   - Stores type information directly in node_index keyed by object_id as the primary interface
        #   - Eliminates awkward name-based input type indexing for nested array elements without names
        #   - Node_index provides the canonical source of truth for InputElementReference types
        class FunctionSignaturePass < PassBase
          def run(errors)
            node_index = get_state(:node_index)
            @node_index = node_index
            @input_metadata = get_state(:input_metadata)
            @input_name_index = get_state(:input_name_index)
            # @decl_shapes = get_state(:decl_shapes) # WHY? BROADCAST IS USING?
            @broadcasts = get_state(:broadcasts)

            # Store type information directly in node_index instead of building separate index
            populate_node_types(node_index)

            if ENV["DEBUG_LOWER"]
              puts "FunctionSignaturePass: Processing #{node_index.size} nodes"
              call_expr_count = node_index.count { |_, entry| entry[:type] == "CallExpression" }
              puts "  CallExpression nodes: #{call_expr_count}"
            end

            # Process all CallExpression nodes in the index
            node_index.each do |object_id, entry|
              next unless entry[:type] == "CallExpression"

              puts "  Skipping cascade_and" if (entry[:fn_name] == :cascade_and) && ENV.fetch("DEBUG_LOWER", nil)

              if ENV["DEBUG_LOWER"]
                node = entry[:node]
                puts "  Processing CallExpression: #{node.fn_name} (object_id: #{object_id}, node.object_id: #{node.object_id})"
                puts "    Match: #{object_id == node.object_id}"
              end

              resolve_function_signature(entry, object_id, errors)
            end

            if ENV["DEBUG_LOWER"]
              puts "FunctionSignaturePass: Completed. Checking final metadata..."
              node_index.each do |object_id, entry|
                next unless entry[:type] == "CallExpression"

                node = entry[:node]
                metadata = entry[:metadata] || {}
                puts "  Node #{node.fn_name} (#{object_id}): metadata keys = #{metadata.keys.inspect}"
              end
            end

            state # Node index is modified in-place
          end

          private

          def resolve_function_signature(entry, object_id, errors)
            node = entry[:node]
            metadata = entry[:metadata] || {}

            # Ensure metadata has effective_fn_name and resolved_name
            metadata[:effective_fn_name] ||= node.fn_name
            metadata[:resolved_name] = metadata[:qualified_name] if metadata[:qualified_name]

            # Skip signature resolution for invalid cascade_and nodes or nodes with skip_signature flag
            if metadata[:invalid_cascade_and] || metadata[:skip_signature]
              if ENV["DEBUG_LOWER"]
                puts "    SKIPPING signature resolution for #{node.fn_name} - will be desugared to identity or skip_signature flag set"
                puts "      metadata: #{metadata.keys.inspect}"
              end
              return
            end

            # Skip signature resolution for ambiguous functions - they will be resolved later in AmbiguityResolverPass
            if metadata[:ambiguous_candidates]
              if ENV["DEBUG_LOWER"]
                puts "    SKIPPING signature resolution for #{node.fn_name} - ambiguous function, will be resolved in AmbiguityResolverPass"
                puts "      candidates: #{metadata[:ambiguous_candidates]&.map(&:name)}"
              end
              return
            end

            puts "    resolve_function_signature for #{node.fn_name}" if ENV["DEBUG_LOWER"]

            # 1) Gather candidate signatures from current registry
            sig_strings = get_function_signatures(entry)
            puts "      Found signatures: #{sig_strings.inspect}" if ENV["DEBUG_LOWER"]
            return if sig_strings.empty?

            begin
              sigs = parse_signatures(sig_strings)
              if ENV["DEBUG_LOWER"]
                puts "      Parsed signatures: #{sigs.length} valid"
                sigs.each_with_index do |sig, i|
                  puts "        [#{i}] #{sig.inspect}"
                  puts "           join_policy: #{sig.join_policy.inspect}" if sig.respond_to?(:join_policy)
                end
              end
            rescue Kumi::Core::Functions::SignatureError => e
              report_error(errors, "Invalid signature for function `#{node.fn_name}`: #{e.message}",
                           location: node.loc, type: :type)
              return
            end

            # 2) Build arg_shapes from current node context
            arg_shapes = build_argument_shapes(node, object_id)
            puts "      Argument shapes: #{arg_shapes.inspect}" if ENV["DEBUG_LOWER"]

            # 2.5) Add variadic signature synthesis if needed
            sigs = synthesize_variadic_signatures(entry, sigs, arg_shapes)

            # 3) Resolve signature
            begin
              plan = Kumi::Core::Functions::SignatureResolver.choose(signatures: sigs, arg_shapes: arg_shapes)
              if ENV["DEBUG_LOWER"]
                puts "      Signature resolution succeeded!"
                puts "        Selected signature: #{plan[:signature].inspect}"
                puts "        Join policy: #{plan[:join_policy].inspect}"
                puts "        Result axes: #{plan[:result_axes].inspect}"
              end
            rescue Kumi::Core::Functions::SignatureMatchError => e
              puts "      Signature resolution failed: #{e.message}" if ENV["DEBUG_LOWER"]
              # Use qualified name for error message if available
              effective_name = entry[:metadata][:qualified_name] || entry[:metadata][:effective_fn_name] || node.fn_name

              # Generate helpful error message
              error_msg = build_signature_error_message(effective_name, arg_shapes, sig_strings, e, node)
              report_error(errors, error_msg, location: node.loc, type: :type)
              return
            end

            # 4) Compute result dtype if function has dtype metadata
            begin
              qualified_name = entry[:metadata][:qualified_name] || effective_name
              fn = registry_v2.resolve(qualified_name)
              if fn.respond_to?(:dtypes) && fn.dtypes && (fn.dtypes[:result] || fn.dtypes["result"])
                arg_types = build_argument_types(node)
                result_dtype = Kumi::Core::Functions::DTypeAdapter.evaluate(fn, arg_types)
                entry[:metadata][:result_dtype] = result_dtype if result_dtype
                puts "      Computed result dtype: #{result_dtype} for #{fn.name} with args #{arg_types.inspect}" if ENV["DEBUG_LOWER"]
              end
            rescue StandardError => e
              puts "      Failed to compute result dtype: #{e.message}" if ENV["DEBUG_LOWER"]
              # Continue - result dtype computation is optional
            end

            # 5) Attach metadata to node index entry
            if ENV["DEBUG_LOWER"]
              puts "      Attaching metadata to entry..."
              puts "        Before: entry[:metadata] = #{entry[:metadata].inspect}"
              puts "        Before: entry[:inferred_scope] = #{entry[:inferred_scope].inspect}"
            end
            attach_signature_metadata(entry, plan)
            # Set inferred_scope as per NEP-20 contract
            entry[:inferred_scope] = Array(plan[:result_axes])
            return unless ENV["DEBUG_LOWER"]

            puts "        After: entry[:metadata] = #{entry[:metadata].inspect}"
            puts "        After: entry[:inferred_scope] = #{entry[:inferred_scope].inspect}"
          end

          def get_function_signatures(entry)
            # Use effective function name (from CascadeDesugarPass) or qualified name or node fn_name
            effective_name = entry[:metadata][:effective_fn_name] || entry[:node].fn_name
            qualified_name = entry[:metadata][:qualified_name] || effective_name
            # Use RegistryV2 for all function resolution
            registry_v2_signatures(qualified_name)
          end

          def registry_v2_signatures(fn_name)
            if ENV["DEBUG_LOWER"]
              puts "        registry_v2_signatures for #{fn_name}"
              puts "          Available functions: #{registry_v2.all_function_names.first(10).inspect}..."
              puts "          Function exists?: #{registry_v2.function_exists?(fn_name.to_s)}"
            end

            # Debug the fetch process step by step
            if ENV["DEBUG_LOWER"]
              begin
                fn = registry_v2.fetch(fn_name)
                puts "          Fetched function: #{fn.class}"
                puts "          Function name: #{fn.name}" if fn.respond_to?(:name)
                puts "          Signatures count: #{fn.signatures.length}" if fn.respond_to?(:signatures)
                if fn.respond_to?(:signatures) && fn.signatures.any?
                  puts "          First signature: #{fn.signatures.first.inspect}"
                  if fn.signatures.first.respond_to?(:to_signature_string)
                    puts "          to_signature_string: #{fn.signatures.first.to_signature_string}"
                  end
                end
              rescue StandardError => e
                puts "          Fetch error: #{e.message}"
                puts "          This means the function is not properly loaded in RegistryV2"
                raise e # Don't fallback - force the issue to be fixed
              end
            end

            result = registry_v2.get_function_signatures(fn_name)

            puts "          Direct lookup result: #{result.inspect}" if ENV["DEBUG_LOWER"]

            raise "No signatures found for #{fn_name} in RegistryV2 - function must be properly defined" if result.empty?

            result
          end

          def build_argument_shapes(node, object_id)
            # Build argument shapes from current analysis context
            node.args.map.with_index do |arg, i|
              shape = infer_arg_shape(arg, @decl_shapes, @broadcasts)

              # Debug shape inference
              puts "        Argument #{i + 1} (#{arg.class}) shape: #{shape.inspect}" if ENV["DEBUG_LOWER"]

              shape
            end
          end

          def build_argument_types(node)
            # Build argument types for dtype computation
            # Use the same type inference logic as TypeCheckerV2
            node.args.map { |arg| infer_expr_type(arg) }
          end

          def infer_expr_type(expr)
            case expr
            when Kumi::Syntax::Literal
              Kumi::Core::Types.infer_from_value(expr.value)

            when Kumi::Syntax::InputReference
              if expr.respond_to?(:name) && @input_metadata[expr.name]
                @input_metadata[expr.name][:type] || :any
              else
                :any
              end

            when Kumi::Syntax::InputElementReference
              # Use node_index as the primary interface for InputElementReference types
              node_entry = @node_index[expr.object_id]
              if node_entry && node_entry[:inferred_type]
                node_entry[:inferred_type]
              else
                # Type not yet populated in node_index - this should be resolved during populate_node_types
                traverse_input_metadata_path(expr) || :any
              end

            when Kumi::Syntax::DeclarationReference
              node_entry[]

            when Kumi::Syntax::CallExpression
              # For nested call expressions, we might not have computed the result dtype yet
              # Fall back to :any for now - this handles the simple case
              :any

            when Kumi::Syntax::ArrayExpression
              # Coarse: unify all element types
              elems = begin
                expr.elements
              rescue StandardError
                []
              end # defensive
              elems.map { |e| infer_expr_type(e) }.reduce(:any) { |acc, t| Kumi::Core::Types.unify(acc, t) }

            else
              :any
            end
          end

          def normalize_shape(axes)
            case axes
            when nil
              [] # scalar
            when Array
              axes.map { |d| d.is_a?(Integer) ? d : d.to_sym }
            else
              [] # defensive fallback
            end
          end

          # Step 1 fix: Use metadata-driven approach instead of broadcast prefix heuristics
          def infer_arg_shape(arg_node, decl_shapes, broadcasts)
            case arg_node
            when Kumi::Syntax::DeclarationReference
              # Get dimensional scope from BroadcastDetector analysis (required)
              broadcast_info = broadcasts&.dig(:vectorized_operations, arg_node.name)
              broadcast_info ||= broadcasts&.dig(:scalar_operations, arg_node.name)
              broadcast_info ||= broadcasts&.dig(:reduction_operations, arg_node.name) # TODO: SEE THIS THROUGH
              broadcast_info&.dig(:dimensional_scope) || [] # TODO!! BAAAD!
            when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference
              # Use precomputed dimensional scope from InputCollector
              if arg_node.respond_to?(:path) && arg_node.path && @input_metadata
                get_dimensional_scope_from_metadata(arg_node.path, @input_metadata)
              else
                []
              end
            else
              []
            end
          end

          # Step 1: Retrieve precomputed dimensional scope from InputCollector
          def get_dimensional_scope_from_metadata(path, input_metadata)
            raise "Path cannot be nil or empty" if path.nil? || path.empty?

            # Navigate to the final field and get its precomputed dimensional_scope
            meta = input_metadata
            path.each do |segment|
              field = meta[segment]
              raise "Path segment '#{segment}' not found in input metadata at #{path}" unless field

              # If this is the final segment, return its precomputed dimensional scope
              return field.dimensional_scope if segment == path.last

              # Navigate to children for next segment
              meta = field.children
              raise "Field '#{segment}' missing children metadata at #{path}" unless meta
            end

            raise "Should not reach here - path traversal failed for #{path}"
          end

          def build_signature_error_message(fn_name, arg_shapes, sig_strings, original_error, node)
            msg = "Function `#{fn_name}` signature mismatch:\n"
            msg << "  Called with: #{format_shapes(arg_shapes)}\n"
            msg << "  Available signatures: #{format_sigs(sig_strings)}\n"

            # Check for common issues
            if arg_shapes.all?(&:empty?)
              msg << "\n  Hint: All arguments appear as scalars (). This often means:\n"
              msg << "    - Vector operations not detected by broadcast analyzer\n"
              msg << "    - Missing array element access patterns (e.g., input.items.field)\n"
              msg << "    - Function called with literal arrays instead of vectorized inputs\n"
            end

            # Add specific hints for known functions
            case fn_name.to_s
            when "struct.searchsorted"
              if arg_shapes == [[], []]
                msg << "\n  Expected: array and value for search (e.g., searchsorted(edges, income))\n"
                msg << "  Try: fn(:searchsorted, input.edges, input.income) for vectorized inputs\n"
              end
            when "array.get"
              if arg_shapes == [[], []]
                msg << "\n  Expected: array and index (e.g., get(rates, index))\n"
                msg << "  Try: fn(:get, rates, index) with proper array shapes\n"
              end
            end

            msg << "\n  Original error: #{original_error.message}"
            msg
          end

          def parse_signatures(sig_strings)
            @sig_cache ||= {}
            sig_strings.map do |s|
              @sig_cache[s] ||= Kumi::Core::Functions::SignatureParser.parse(s)
            end
          end

          def format_shapes(shapes)
            shapes.map { |ax| "(#{ax.join(',')})" }.join(", ")
          end

          def format_sigs(sig_strings)
            sig_strings.join(" | ")
          end

          def attach_signature_metadata(entry, plan)
            # Attach signature resolution results to the node index entry
            # This way other passes can access the metadata via the node index
            metadata = entry[:metadata]

            if ENV["DEBUG_LOWER"]
              puts "        attach_signature_metadata called"
              puts "          entry[:metadata] exists: #{!!metadata}"
              puts "          plan: #{plan.class} with signature=#{plan.signature.to_signature_string}"
            end

            attach_core_signature_data(metadata, plan)
            attach_shape_contract(metadata, plan)

            return unless ENV["DEBUG_LOWER"]

            puts "          Final metadata keys: #{metadata.keys.inspect}"
            puts "          join_policy value: #{metadata[:join_policy].inspect}"
          end

          def attach_core_signature_data(metadata, plan)
            metadata[:selected_signature]  = plan[:signature] # NEP-20 contract requirement
            metadata[:result_axes]         = plan[:result_axes]        # e.g., [:i, :j]
            metadata[:join_policy]         = plan[:join_policy]        # nil | :zip | :product
            metadata[:dropped_axes]        = plan[:dropped_axes]       # e.g., [:j] for reductions
            metadata[:effective_signature] = plan[:effective_signature] # Normalized for lowering
            metadata[:dim_env]             = plan[:env]                # Dimension bindings (for matmul)
            metadata[:signature_score]     = plan[:score]              # Match quality
          end

          def attach_shape_contract(metadata, plan)
            # Attach shape contract for lowering convenience
            metadata[:shape_contract] = {
              in: plan[:effective_signature][:in_shapes],
              out: plan[:effective_signature][:out_shape],
              join: plan[:effective_signature][:join_policy]
            }
          end

          def registry_v2_enabled?
            ENV["KUMI_FN_REGISTRY_V2"] == "1"
          end

          def nep20_flex_enabled?
            ENV["KUMI_ENABLE_FLEX"] == "1"
          end

          def nep20_bcast1_enabled?
            ENV["KUMI_ENABLE_BCAST1"] == "1"
          end

          def synthesize_variadic_signatures(entry, existing_signatures, arg_shapes)
            # Check if function is variadic
            fn = get_function_for_entry(entry)
            unless fn&.variadic
              puts "      Function #{fn&.name || 'unknown'} is not variadic, skipping synthesis" if ENV["DEBUG_LOWER"]
              return existing_signatures
            end

            provided_arity = arg_shapes.length
            puts "      Function #{fn.name} is variadic, provided_arity=#{provided_arity}" if ENV["DEBUG_LOWER"]

            # Check if we already have a signature with the exact arity
            if ENV["DEBUG_LOWER"]
              puts "        Checking for exact match with provided_arity=#{provided_arity}"
              existing_signatures.each_with_index do |sig, i|
                puts "        [#{i}] sig.in_shapes.length=#{sig.in_shapes.length}, in_shapes=#{sig.in_shapes.inspect}, sig=#{sig.inspect}"
              end
            end
            exact_match = existing_signatures.find { |sig| sig.in_shapes.length == provided_arity }
            if exact_match
              puts "        Found exact match for arity #{provided_arity}: #{exact_match.inspect}" if ENV["DEBUG_LOWER"]
              return existing_signatures
            elsif ENV["DEBUG_LOWER"]
              puts "        No exact match found for arity #{provided_arity}"
            end

            # Find template signatures for synthesis
            template_sigs = existing_signatures.select do |sig|
              template_arity = sig.in_shapes.length
              template_arity <= provided_arity
            end

            if template_sigs.empty?
              puts "        No suitable template signatures found for variadic synthesis" if ENV["DEBUG_LOWER"]
              return existing_signatures
            end

            # Use the signature with the highest arity as template
            template = template_sigs.max_by { |sig| sig.in_shapes.length }
            puts "        Using template: #{template.inspect}" if ENV["DEBUG_LOWER"]

            # Synthesize new signature by extending the template
            synthesized = synthesize_signature_for_arity(template, provided_arity, fn)
            if synthesized
              puts "        Synthesized signature: #{synthesized.inspect}" if ENV["DEBUG_LOWER"]
              return existing_signatures + [synthesized]
            end

            existing_signatures
          end

          def synthesize_signature_for_arity(template, target_arity, fn)
            return nil if target_arity <= template.in_shapes.length

            # For variadic functions, extend the last template dimension pattern
            template_in_shapes = template.in_shapes
            last_shape = template_in_shapes.last || []

            # Create new signature with repeated last pattern
            new_in_shapes = template_in_shapes.dup
            (target_arity - template_in_shapes.length).times do
              new_in_shapes << last_shape
            end

            # Preserve output shape and join policy from template
            Kumi::Core::Functions::Signature.new(
              in_shapes: new_in_shapes,
              out_shape: template.out_shape,
              join_policy: fn.zip_policy || template.join_policy,
              raw: "synthesized_variadic_#{target_arity}_args"
            )
          rescue StandardError => e
            puts "        Failed to synthesize signature: #{e.message}" if ENV["DEBUG_LOWER"]
            nil
          end

          def get_function_for_entry(entry)
            qualified_name = entry[:metadata][:qualified_name]
            return nil unless qualified_name

            registry_v2.resolve(qualified_name)
          rescue StandardError
            nil
          end

          def populate_node_types(node_index)
            # Store type information for InputElementReference nodes in node_index
            node_index.each do |object_id, entry|
              next unless entry[:type] == "InputElementReference"

              node = entry[:node]
              next unless node.respond_to?(:path) && node.path

              # Traverse input metadata to find the type for this path
              inferred_type = traverse_input_metadata_path(node)
              entry[:inferred_type] = inferred_type if inferred_type
            end
          end

          def traverse_input_metadata_path(expr)
            return nil unless expr.respond_to?(:path) && expr.path

            path = Array(expr.path)
            return nil if path.empty?

            # Start with the root field
            root_name = path.first
            current_meta = @input_metadata[root_name]
            return nil unless current_meta

            # If this is just a root reference, return its type
            return current_meta[:type] if path.length == 1

            # Traverse the nested path
            path[1..-1].each do |field_name|
              return nil unless current_meta[:children]

              current_meta = current_meta[:children][field_name]
              return nil unless current_meta
            end

            current_meta[:type]
          end
        end
      end
    end
  end
end
