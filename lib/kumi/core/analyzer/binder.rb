# frozen_string_literal: true

require "json"
require "digest"

module Kumi
  module Core
    module Analyzer
      module Binder
        OPS_WITH_KERNELS = %i[KernelCall Accumulate Fold].freeze

        module_function

        def bind(lir_decls, registry, target:)
          bindings = []
          target_sym = target.to_sym

          lir_decls.each do |decl_name, decl|
            Array(decl[:operations]).each do |op|
              opcode = op.opcode
              next unless OPS_WITH_KERNELS.include?(opcode)

              fn_name = op.attributes[:fn]
              raise "KernelCall at #{op.location} is missing :fn attribute" unless fn_name

              function = registry.function(fn_name)
              fn_id = function.id

              kernel = registry.kernel_for(fn_id, target: target_sym)
              id = kernel.id
              impl = kernel.impl
              inline = kernel.inline
              fold_inline = kernel.fold_inline
              dtype = op.stamp&.dig("dtype")

              attrs = {}

              attrs["inline"] = inline if inline
              attrs["fold_inline"] = fold_inline if fold_inline

              # TODO: Make this logic clear, we are mixing reducers functions that works over scalars collections and eachwise, this is confusing.
              if function.reduce? && opcode != :Fold
                case function.reduction_strategy
                when :identity

                  identity = registry.kernel_identity_for(fn_id, dtype: dtype, target: target_sym)
                  attrs["identity"] = identity if identity
                when :first_element
                  attrs["first_element"] = true
                end
              end

              fname = fn_id.split(".").join("_")

              bindings << {
                "decl" => decl_name.to_s,
                "op_result_reg" => op.result_register,
                "fn" => fn_name, # Original function name/alias
                "fn_id" => fn_id, # Resolved canonical function ID
                "fname" => fname, # Sanitized function name for use in Ruby method names
                "id" => id,
                "impl" => impl,
                "attrs" => attrs
              }
            end
          end

          deduplicated = deduplicate_kernel_impls(bindings)

          {
            "lir_ref" => sha256_lir_ref(lir_decls),
            "target" => target.to_s,
            "registry_ref" => registry.registry_ref,
            "bindings" => deduplicated[:bindings],
            "kernels" => deduplicated[:kernels]
          }
        end

        def deduplicate_kernel_impls(bindings)
          kernels = {}
          deduplicated_bindings = []

          bindings.each do |binding|
            id = binding["id"]
            impl = binding["impl"]
            attrs = binding["attrs"]

            if kernels.key?(id)
              raise "Inconsistent impl for #{id}" unless kernels[id]["impl"] == impl

              kernels[id]["attrs"].merge!(attrs)
            else
              kernels[id] = {
                "id" => id,
                "fn_id" => binding["fn_id"],
                "impl" => impl,
                "attrs" => attrs
              }
            end

            deduplicated_bindings << binding.reject { |k, _| %w[impl attrs].include?(k) }
          end

          {
            bindings: deduplicated_bindings,
            kernels: kernels.values
          }
        end

        def sha256_lir_ref(lir_decls)
          canonical_decls = lir_decls.transform_values do |decl|
            decl[:operations].map(&:to_h)
          end

          json = JSON.generate(canonical_decls, { ascii_only: true, array_nl: "", object_nl: "", indent: "", space: "", space_before: "" })
          "sha256:#{Digest::SHA256.hexdigest(json)}"
        end
      end
    end
  end
end
