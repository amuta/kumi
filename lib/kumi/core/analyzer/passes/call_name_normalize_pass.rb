# frozen_string_literal: true

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
              next unless entry[:type] == "CallExpression"

              begin
                process_call_expression(entry)
              rescue StandardError => e
                # This is early in the pipeline, but we can still provide some context
                dump_on_fail_early(e, entry)
                raise # Re-raise to maintain error propagation
              end
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
              ENV.fetch("DEBUG_NORMALIZE", nil) && puts("  Skipping call_id=#{node.object_id} raw=#{node.fn_name} - #{reason}")
              return
            end

            canonical_name = Kumi::Core::Naming::BasenameNormalizer.normalize(before)

            # Resolve canonical name to qualified registry name
            result = resolve_to_qualified_name_with_function(canonical_name, node.args.size)

            # Annotate with both canonical and qualified names for downstream passes
            entry[:metadata][:canonical_name] = canonical_name
            if result[:function].respond_to?(:ambiguous?) && result[:function].ambiguous?
              # Don't set qualified_name for ambiguous functions - leave for AmbiguityResolverPass
              entry[:metadata][:ambiguous_candidates] = result[:function].candidates
            else
              entry[:metadata][:qualified_name] = result[:qualified_name]
            end

            warn_deprecated(before, canonical_name) if (before != canonical_name) && ENV.fetch("WARN_DEPRECATED_FUNCS", nil)

            qualified_name_for_debug = entry[:metadata][:qualified_name]
            ENV.fetch("DEBUG_NORMALIZE",
                      nil) && puts("  Normalized call_id=#{node.object_id} raw=#{node.fn_name} effective=#{before} qualified=#{qualified_name_for_debug}")
          end

          def resolve_to_qualified_name_with_function(canonical_name, arity = nil)
            # Use RegistryV2 to resolve the qualified name based on basename and arity
            function = registry_v2.resolve(canonical_name.to_s, arity: arity)
            
            # Handle ambiguous functions - return special marker for later resolution
            if function.respond_to?(:ambiguous?) && function.ambiguous?
              return { qualified_name: :ambiguous, function: function }
            end
            
            { qualified_name: function.name, function: function }
          end

          def resolve_to_qualified_name(canonical_name, arity = nil)
            result = resolve_to_qualified_name_with_function(canonical_name, arity)
            result[:qualified_name]
          end

          def warn_deprecated(before, after)
            warn "[kumi] deprecated function name #{before.inspect} → #{after.inspect}"
          end

          def dump_on_fail_early(e, entry)
            path = ENV.fetch("DUMP_IR_ON_FAIL", nil)
            return unless path

            File.open(path, "w") do |io|
              io.puts("EXCEPTION: #{e.class}: #{e.message}")
              io.puts("Context: Failed during function name normalization")
              io.puts("Function: #{entry[:node]&.fn_name}")
              io.puts("Args: #{entry[:node]&.args&.size}")
              io.puts("")
              io.puts("Full error:\n#{e.message}\n#{e.backtrace.join("\n")}")
              io.puts("")
              io.puts("-- EARLY FAILURE: No IR available yet --")
            end
            warn "IR dump (early failure) written to #{path}"
          end
        end
      end
    end
  end
end
