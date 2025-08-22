# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Extract IR-level dependencies for VM execution optimization
        # DEPENDENCIES: :ir_module from LowerToIRPass
        # PRODUCES: :ir_dependencies - Hash mapping declaration names to referenced bindings
        #           :ir_name_index - Hash mapping stored binding names to producing declarations
        # INTERFACE: new(schema, state).run(errors)
        #
        # NOTE: This pass extracts actual IR-level dependencies by analyzing :ref operations
        # in the generated IR, providing the dependency information needed for optimized VM scheduling.
        class IRDependencyPass < PassBase
          def run(errors)
            ir_module = get_state(:ir_module, required: true)

            ir_dependencies = build_ir_dependency_map(ir_module)
            ir_name_index = build_ir_name_index(ir_module)

            state.with(:ir_dependencies, ir_dependencies).with(:ir_name_index, ir_name_index)
          end

          private

          # Build a map of declaration -> [stored_bindings_it_references] from the IR
          def build_ir_dependency_map(ir_module)
            deps_map = {}

            ir_module.decls.each do |decl|
              refs = []
              decl.ops.each do |op|
                refs << op.attrs[:name] if op.tag == :ref
              end
              deps_map[decl.name] = refs
            end

            deps_map.freeze
          end

          # Build name index to map stored binding names to their producing declarations
          def build_ir_name_index(ir_module)
            ir_name_index = {}

            ir_module.decls.each do |decl|
              # Map the primary declaration name
              ir_name_index[decl.name] = decl

              # Also map any vectorized twin names produced by this declaration
              decl.ops.each do |op|
                if op.tag == :store
                  stored_name = op.attrs[:name]
                  ir_name_index[stored_name] = decl
                end
              end
            end

            ir_name_index.freeze
          end
        end
      end
    end
  end
end
