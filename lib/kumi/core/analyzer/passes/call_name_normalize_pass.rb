# frozen_string_literal: true

require_relative "../../naming/basename_normalizer"

module Kumi
  module Core
    module Analyzer
      module Passes
        # INPUT:  :declarations (ASTs), :node_index (built earlier)
        # OUTPUT: metadata annotations with fully qualified function names
        # GOAL:   resolve canonical basenames to registry qualified names (e.g. :add → "core.add")
        class CallNameNormalizePass < PassBase
          def run(errors)
            node_index = get_state(:node_index, required: true)

            # Process all nodes in the index (which includes all CallExpression nodes after CascadeDesugarPass)
            node_index.each do |object_id, entry|
              next unless entry[:type] == 'CallExpression'
              
              process_call_expression(entry)
            end

            state
          end

          private

          def process_call_expression(entry)
            node = entry[:node]
            
            # Use effective_fn_name from CascadeDesugarPass if available, otherwise use node.fn_name
            before = if entry[:metadata] && entry[:metadata][:effective_fn_name]
              entry[:metadata][:effective_fn_name]
            else
              node.fn_name
            end
            
            # Skip if already processed by CascadeDesugarPass and has qualified_name or skip_signature
            if entry[:metadata] && (entry[:metadata][:qualified_name] || entry[:metadata][:skip_signature])
              reason = entry[:metadata][:qualified_name] ? "already has qualified_name: #{entry[:metadata][:qualified_name]}" : "skip_signature flag set"
              ENV["DEBUG_NORMALIZE"] && puts("  Skipping call_id=#{node.object_id} raw=#{node.fn_name} - #{reason}")
              return
            end
            
            canonical_name = Kumi::Core::Naming::BasenameNormalizer.normalize(before)

            # Resolve canonical name to qualified registry name
            qualified_name = resolve_to_qualified_name(canonical_name, node.args.size)
            
            # Annotate with both canonical and qualified names for downstream passes
            entry[:metadata][:canonical_name] = canonical_name
            entry[:metadata][:qualified_name] = qualified_name
            
            if before != canonical_name
              warn_deprecated(before, canonical_name) if ENV["WARN_DEPRECATED_FUNCS"]
            end
            
            ENV["DEBUG_NORMALIZE"] && puts("  Normalized call_id=#{node.object_id} raw=#{node.fn_name} effective=#{before} qualified=#{qualified_name}")
          end

          def resolve_to_qualified_name(canonical_name, arity = nil)
            # Use RegistryV2 to resolve the qualified name based on basename and arity
            function = registry_v2.resolve(canonical_name.to_s, arity: arity)
            function.name
          end

          def warn_deprecated(before, after)
            $stderr.puts "[kumi] deprecated function name #{before.inspect} → #{after.inspect}"
          end
        end
      end
    end
  end
end