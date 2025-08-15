# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Apply NEP-20 signature resolution to function calls
        # DEPENDENCIES: :node_index from Toposorter, :broadcast_metadata (optional)
        # PRODUCES: Signature metadata in node_index for CallExpression nodes
        # INTERFACE: new(schema, state).run(errors)
        class FunctionSignaturePass < PassBase
          def run(errors)
            node_index = get_state(:node_index, required: true)

            if ENV["DEBUG_LOWER"]
              puts "FunctionSignaturePass: Processing #{node_index.size} nodes"
              call_expr_count = node_index.count { |_, entry| entry[:type] == "CallExpression" }
              puts "  CallExpression nodes: #{call_expr_count}"
            end

            # Process all CallExpression nodes in the index
            node_index.each do |object_id, entry|
              next unless entry[:type] == "CallExpression"

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

            # Skip signature resolution for cascade_and nodes that will be desugared
            if metadata[:desugar_to_identity] || metadata[:desugared_to] || metadata[:invalid_cascade_and]
              if ENV["DEBUG_LOWER"]
                puts "    SKIPPING signature resolution for #{node.fn_name} - will be desugared"
                puts "      metadata: #{metadata.keys.inspect}"
              end
              return
            end

            if ENV["DEBUG_LOWER"]
              puts "    resolve_function_signature for #{node.fn_name}"
            end

            # 1) Gather candidate signatures from current registry
            sig_strings = get_function_signatures(entry)
            if ENV["DEBUG_LOWER"]
              puts "      Found signatures: #{sig_strings.inspect}"
            end
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
            if ENV["DEBUG_LOWER"]
              puts "      Argument shapes: #{arg_shapes.inspect}"
            end

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
              if ENV["DEBUG_LOWER"]
                puts "      Signature resolution failed: #{e.message}"
              end
              # Use qualified name for error message if available
              effective_name = entry[:metadata][:qualified_name] || entry[:metadata][:effective_fn_name] || node.fn_name
              report_error(errors, 
                          "Signature mismatch for `#{effective_name}` with args #{format_shapes(arg_shapes)}. Candidates: #{format_sigs(sig_strings)}. #{e.message}",
                          location: node.loc, type: :type)
              return
            end

            # 4) Attach metadata to node index entry
            if ENV["DEBUG_LOWER"]
              puts "      Attaching metadata to entry..."
              puts "        Before: entry[:metadata] = #{entry[:metadata].inspect}"
            end
            attach_signature_metadata(entry, plan)
            if ENV["DEBUG_LOWER"]
              puts "        After: entry[:metadata] = #{entry[:metadata].inspect}"
            end
          end

          def get_function_signatures(entry)
            # Use effective function name (from CascadeDesugarPass) or qualified name or node fn_name
            effective_name = entry[:metadata][:effective_fn_name] || entry[:node].fn_name
            qualified_name = entry[:metadata][:qualified_name] || effective_name
            # Use RegistryV2 only - no fallback to legacy registry
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
                  puts "          to_signature_string: #{fn.signatures.first.to_signature_string}" if fn.signatures.first.respond_to?(:to_signature_string)
                end
              rescue => fetch_error
                puts "          Fetch error: #{fetch_error.message}"
                puts "          This means the function is not properly loaded in RegistryV2"
                raise fetch_error  # Don't fallback - force the issue to be fixed
              end
            end
            
            result = registry_v2.get_function_signatures(fn_name)
            
            if ENV["DEBUG_LOWER"]
              puts "          Direct lookup result: #{result.inspect}"
            end
            
            if result.empty?
              raise "No signatures found for #{fn_name} in RegistryV2 - function must be properly defined"
            end
            
            result
          end

          def legacy_registry_signatures(node)
            # Try to get signatures from the current registry
            # For now, we'll create basic signatures from the current registry format

            meta = Kumi::Registry.signature(node.fn_name)

            # Check if the function already has NEP-20 signatures
            return meta[:signatures] if meta[:signatures] && meta[:signatures].is_a?(Array)

            # Otherwise, create a basic signature from arity
            # This is a bridge until we have full NEP-20 signatures in the registry
            create_basic_signature(meta[:arity])
          rescue Kumi::Errors::UnknownFunction
            # For now, return empty array - function existence will be caught by TypeChecker
            []
          end

          def create_basic_signature(arity)
            return [] if arity.nil? || arity < 0 # Variable arity - skip for now

            case arity
            when 0
              ["()->()"] # Scalar function
            when 1
              ["()->()", "(i)->(i)"] # Scalar or element-wise
            when 2
              ["(),()->()", "(i),(i)->(i)"] # Scalar or element-wise binary
            else
              # For higher arity, just provide scalar signature
              args = (["()"] * arity).join(",")
              ["#{args}->()"]
            end
          end

          def build_argument_shapes(node, object_id)
            # Build argument shapes from current analysis context
            node.args.map do |arg|
              axes = get_broadcast_metadata(arg.object_id)
              normalize_shape(axes)
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

          def get_broadcast_metadata(arg_object_id)
            # Try to get broadcast metadata from existing analysis state
            broadcast_meta = get_state(:broadcast_metadata, required: false)
            return nil unless broadcast_meta

            # Look up by node object_id
            broadcast_meta[arg_object_id]&.dig(:axes)
          end

          def parse_signatures(sig_strings)
            @sig_cache ||= {}
            sig_strings.map do |s|
              @sig_cache[s] ||= Kumi::Core::Functions::SignatureParser.parse(s)
            end
          end

          def format_shapes(shapes)
            shapes.map { |ax| "(#{ax.join(',')})" }.join(', ')
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
              puts "          plan keys: #{plan.keys.inspect}"
            end

            attach_core_signature_data(metadata, plan)
            attach_shape_contract(metadata, plan)

            if ENV["DEBUG_LOWER"]
              puts "          Final metadata keys: #{metadata.keys.inspect}"
              puts "          join_policy value: #{metadata[:join_policy].inspect}"
            end
          end

          def attach_core_signature_data(metadata, plan)
            metadata[:signature]           = plan[:signature]
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
              in:   plan[:effective_signature][:in_shapes],
              out:  plan[:effective_signature][:out_shape],
              join: plan[:effective_signature][:join_policy]
            }
          end

          def registry_v2_enabled?
            ENV["KUMI_FN_REGISTRY_V2"] == "1"
          end

          def registry_v2
            @registry_v2 ||= Kumi::Core::Functions::RegistryV2.load_from_file
          end

          def nep20_flex_enabled?
            ENV["KUMI_ENABLE_FLEX"] == "1"
          end

          def nep20_bcast1_enabled?
            ENV["KUMI_ENABLE_BCAST1"] == "1"
          end
        end
      end
    end
  end
end
