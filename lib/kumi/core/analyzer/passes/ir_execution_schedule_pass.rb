# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # PRODUCES: :execution_schedules => { store_name(Symbol) => [Decl, ...] }
        class IRExecutionSchedulePass < PassBase
          def run(_errors)
            ir          = get_state(:ir_module, required: true)
            deps        = get_state(:ir_dependencies, required: true)    # decl_name => [binding_name, ...]
            name_index  = get_state(:ir_name_index, required: true)      # binding_name => Decl  (← use IR-specific index)

            by_name     = ir.decls.to_h { |d| [d.name, d] }
            pos         = ir.decls.each_with_index.to_h                  # for deterministic ordering

            closure_cache = {}
            visiting      = {}

            visit = lambda do |dn|
              return closure_cache[dn] if closure_cache.key?(dn)

              raise Kumi::Core::Errors::TypeError, "cycle detected in IR at #{dn.inspect}" if visiting[dn]

              visiting[dn] = true

              # Resolve binding refs -> producing decl names
              preds = Array(deps[dn]).filter_map { |b| name_index[b]&.name }.uniq

              # Deterministic order: earlier IR decls first
              preds.sort_by! { |n| pos[n] || Float::INFINITY }

              order = []
              preds.each do |p|
                next if p == dn # guard against self-deps; treat as error if you prefer

                order.concat(visit.call(p))
              end
              order << dn unless order.last == dn

              visiting.delete(dn)
              closure_cache[dn] = order.uniq.freeze
            end

            schedules = {}

            ir.decls.each do |decl|
              target_names = [decl.name] + decl.ops.select { _1.tag == :store }.map { _1.attrs[:name] }

              seq = visit.call(decl.name).map { |dn| by_name.fetch(dn) }.freeze

              target_names.each do |t|
                if schedules.key?(t) && schedules[t] != seq
                  raise Kumi::Core::Errors::TypeError,
                        "duplicate schedule target #{t.inspect} produced by #{schedules[t].last.name} and #{decl.name}"
                end
                schedules[t] = seq
              end
            end

            state.with(:ir_execution_schedules, schedules.freeze)
          end
        end
      end
    end
  end
end
