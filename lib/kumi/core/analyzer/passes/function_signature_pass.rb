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

            # Process all CallExpression nodes in the index
            node_index.each do |object_id, entry|
              next unless entry[:type] == "CallExpression"

              resolve_function_signature(entry, object_id, errors)
            end

            state # Node index is modified in-place
          end

          private

          def resolve_function_signature(entry, object_id, errors)
            node = entry[:node]

            # 1) Gather candidate signatures from current registry
            sig_strings = get_function_signatures(node)
            return if sig_strings.empty?

            begin
              sigs = parse_signatures(sig_strings)
            rescue Kumi::Core::Functions::SignatureError => e
              report_error(errors, "Invalid signature for function `#{node.fn_name}`: #{e.message}",
                           location: node.loc, type: :type)
              return
            end

            # 2) Build arg_shapes from current node context
            arg_shapes = build_argument_shapes(node, object_id)

            # 3) Resolve signature
            begin
              plan = Kumi::Core::Functions::SignatureResolver.choose(signatures: sigs, arg_shapes: arg_shapes)
            rescue Kumi::Core::Functions::SignatureMatchError => e
              report_error(errors, 
                          "Signature mismatch for `#{node.fn_name}` with args #{format_shapes(arg_shapes)}. Candidates: #{format_sigs(sig_strings)}. #{e.message}",
                          location: node.loc, type: :type)
              return
            end

            # 4) Attach metadata to node index entry
            attach_signature_metadata(entry, plan)
          end

          def get_function_signatures(node)
            # Use RegistryV2 if enabled, otherwise fall back to legacy registry
            if registry_v2_enabled?
              registry_v2_signatures(node)
            else
              legacy_registry_signatures(node)
            end
          end

          def registry_v2_signatures(node)
            registry_v2.get_function_signatures(node.fn_name)
          rescue => e
            # If RegistryV2 fails, fall back to legacy
            legacy_registry_signatures(node)
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

            attach_core_signature_data(metadata, plan)
            attach_shape_contract(metadata, plan)
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
