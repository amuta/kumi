# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Load Input Common Subexpression Elimination Pass
        #
        # Eliminates redundant load_input operations by reusing loads that
        # were already stored by earlier declarations.
        #
        # OPTIMIZATION STRATEGY:
        # - Cross-declaration load reuse: If a load_input with the same
        #   (plan_id, scope, is_scalar, has_idx) was already stored by an
        #   earlier declaration, rewrite later identical loads to ref the
        #   stored value instead of re-loading.
        # - Only reuses producers that appear earlier in module order
        #   (no reordering/hoisting).
        # - Safe because interpreter's outputs persist across declarations
        #   and ref operations resolve previously stored values.
        #
        # REQUIREMENTS:
        # - Must run after LowerToIR pass
        # - IR module must be available in state
        #
        # DEBUG:
        # - Set DEBUG_LOAD_CSE=1 to see optimization decisions
        class LoadInputCSE < PassBase
          def run(_errors)
            ir = get_state(:ir_module, required: true)
            return state unless ir&.decls

            debug = ENV.fetch("DEBUG_LOAD_CSE", nil)

            # Map: key -> { name:, decl_index: }
            producers = {}

            puts "LOAD_CSE: Analyzing #{ir.decls.length} declarations" if debug

            # First pass: find canonical producers (earliest decl that stores a given load)
            ir.decls.each_with_index do |decl, di|
              decl.ops.each_with_index do |op, oi|
                next unless op.tag == :load_input

                key = load_key(op)
                # Does this decl store that slot under a name?
                store_name = name_storing_slot(decl.ops, oi)
                next unless store_name

                # Keep earliest producer only
                unless producers.key?(key)
                  producers[key] = { name: store_name, decl_index: di }
                  puts "LOAD_CSE: Found producer #{store_name} in decl #{di} for key #{key.inspect}" if debug
                end
              end
            end

            puts "LOAD_CSE: Found #{producers.size} unique load patterns" if debug

            # Second pass: rewrite later identical loads to refs
            optimizations = 0
            new_decls = ir.decls.each_with_index.map do |decl, di|
              new_ops = decl.ops.each_with_index.map do |op, oi|
                next op unless op.tag == :load_input

                key = load_key(op)
                prod = producers[key]

                # Only rewrite if producer is in an earlier decl
                if prod && prod[:decl_index] < di
                  optimizations += 1
                  puts "LOAD_CSE: Replacing load_input in #{decl.name}[#{oi}] with ref to #{prod[:name]}" if debug
                  Kumi::Core::IR::Ops.Ref(prod[:name])
                else
                  op
                end
              end

              Kumi::Core::IR::Decl.new(
                name: decl.name,
                kind: decl.kind,
                shape: decl.shape,
                ops: new_ops
              )
            end

            puts "LOAD_CSE: Applied #{optimizations} optimizations" if debug

            new_ir = Kumi::Core::IR::Module.new(inputs: ir.inputs, decls: new_decls)
            state.with(:ir_module, new_ir)
          end

          private

          # Generate a unique key for a load_input operation based on its attributes
          def load_key(op)
            attrs = op.attrs || {}
            [
              :load_input,
              attrs[:plan_id],
              Array(attrs[:scope]),
              !!attrs[:is_scalar],
              !!attrs[:has_idx]
            ]
          end

          # Find a store operation that names the given slot index
          def name_storing_slot(ops, slot_id)
            ops.each do |op|
              next unless op.tag == :store

              src = op.args && op.args[0]
              return op.attrs[:name] if src == slot_id
            end
            nil
          end
        end
      end
    end
  end
end
