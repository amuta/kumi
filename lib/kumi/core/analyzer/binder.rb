require "json"
require "digest"

module Kumi
  module Core
    module Analyzer
      module Binder
        module_function

        def bind(irv2_module, registry, target:)
          bindings = []

          # Find Map and Reduce operations that need kernel binding
          irv2_module.declarations.each do |decl_name, decl|
            decl.operations.each do |op|
              next unless %i[Map Reduce].include?(op.op)

              fn = op.attrs[:fn]
              next unless fn

              kernel_id = registry.pick(fn)
              impl = registry.impl_for(kernel_id)
              
              # Extract dtype from operation stamp and get identity if available
              dtype = op.stamp["dtype"]
              attrs = {}
              begin
                identity = registry.identity(kernel_id, dtype)
                attrs["identity"] = identity if identity
              rescue
                # Not all kernels have identity values (only reductions do)
              end
              
              bindings << {
                "decl" => decl_name.to_s,
                "op" => op.id,
                "fn" => fn,
                "kernel_id" => kernel_id,
                "impl" => impl,
                "attrs" => attrs
              }
            end
          end

          deduplicated = deduplicate_kernel_impls(bindings)
          
          {
            "ir_ref" => sha256_ir_ref(irv2_module),
            "target" => target.to_s,
            "registry_ref" => registry.registry_ref,
            "bindings" => deduplicated[:bindings],
            "kernels" => deduplicated[:kernels]
          }
        end

        # Separate kernel implementations from operation bindings
        # Returns { bindings: [...], kernels: {...} } where:
        # - bindings: operation-level mappings without duplicate impl strings  
        # - kernels: unique kernel_id => {impl, attrs} mappings
        def deduplicate_kernel_impls(bindings)
          kernels = {}
          deduplicated_bindings = []
          
          bindings.each do |binding|
            kernel_id = binding["kernel_id"]
            impl = binding["impl"]
            attrs = binding["attrs"]
            
            # Store unique kernel implementation and attributes
            if kernels.key?(kernel_id)
              unless kernels[kernel_id]["impl"] == impl
                raise "Inconsistent impl for #{kernel_id}: #{impl} vs #{kernels[kernel_id]["impl"]}"
              end
              # Merge attrs if present
              if attrs
                kernels[kernel_id]["attrs"] = (kernels[kernel_id]["attrs"] || {}).merge(attrs)
              end
            else
              kernels[kernel_id] = {"kernel_id" => kernel_id, "impl" => impl, "attrs" => attrs || {}}
            end
            
            # Store operation binding without impl and attrs duplication
            deduplicated_bindings << binding.reject { |k, _| ["impl", "attrs"].include?(k) }
          end
          
          {
            bindings: deduplicated_bindings,
            kernels: kernels.values
          }
        end

        def sha256_ir_ref(irv2_module)
          # Create canonical representation of the IR for stable hashing
          canonical = {
            "declarations" => irv2_module.declarations.transform_values do |decl|
              {
                "operations" => decl.operations.map do |op|
                  {
                    "id" => op.id,
                    "op" => op.op.to_s,
                    "args" => serialize_args(op),
                    "attrs" => op.attrs
                  }
                end,
                "result" => decl.result.id,
                "parameters" => decl.parameters
              }
            end,
            "metadata" => irv2_module.metadata
          }

          # Generate stable SHA256 hash
          json = JSON.generate(canonical, { ascii_only: true, array_nl: "", object_nl: "", indent: "", space: "", space_before: "" })
          "sha256:#{Digest::SHA256.hexdigest(json)}"
        end

        def serialize_args(op)
          # Handle mixed args (Values and literals) based on operation type
          case op.op
          when :LoadInput, :LoadDeclaration, :LoadDecl, :Const
            # These operations have literals/strings in args
            op.args
          else
            # These operations should have Value objects in args
            op.args.map { |arg| arg.respond_to?(:id) ? arg.id : arg }
          end
        end
      end
    end
  end
end
