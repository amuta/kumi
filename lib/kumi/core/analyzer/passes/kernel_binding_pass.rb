# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class KernelBindingPass < PassBase
          # In:  state[:irv2_module]
          # Out: state[:binding_manifest]
          def run(errors)
            irv2_module = get_state(:irv2_module, required: true)
            
            # Load kernel registry for target backend
            target_backend = :ruby
            registry = load_kernel_registry(target_backend)
            
            # Generate binding manifest
            manifest = Binder.bind(irv2_module, registry, target: target_backend)
            
            state.with(:binding_manifest, manifest)
          end

          private

          def load_kernel_registry(backend)
            # Find project root and build kernel path
            project_root = File.expand_path("../../../../../../", __FILE__)
            kernel_dir = File.join(project_root, "data/kernels/#{backend}")
            KernelRegistry.load_dir(kernel_dir)
          end
        end
      end
    end
  end
end