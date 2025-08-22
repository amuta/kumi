# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Builds a precomputed execution schedule per exposed binding (incl. __vec twins).
        # DEPENDS ON: :ir_module, :ir_dependencies, :name_index
        # PRODUCES: :execution_schedules => { store_name(Symbol) => [Decl, ...] }
        class ExecutionSchedulePass < PassBase
          def run(_errors)
            ir          = get_state(:ir_module, required: true)
            deps        = get_state(:ir_dependencies, required: true) # decl_name => [ref_name, ...]
            name_index  = get_state(:name_index, required: true)      # store_name => Decl

            by_name = ir.decls.map { |d| [d.name, d] }.to_h

            # Precompute closure per declaration name
            closure_cache = {}
            dfs = lambda do |decl_name|
              return closure_cache[decl_name] if closure_cache.key?(decl_name)

              seen = {}
              order = []

              visit = lambda do |dn|
                return if seen[dn]

                seen[dn] = true
                Array(deps[dn]).each do |ref_binding|
                  producer = name_index[ref_binding]
                  visit.call(producer.name) if producer
                end
                order << dn
              end

              visit.call(decl_name)
              closure_cache[decl_name] = order
            end

            schedules = {}

            ir.decls.each do |decl|
              # All “store”d names produced by this decl are valid targets
              target_names = [decl.name] +
                             decl.ops.select { |op| op.tag == :store }.map { |op| op.attrs[:name] }

              # Compute topo-closure of dependencies for this decl
              names = dfs.call(decl.name)
              seq   = names.map { |dn| by_name.fetch(dn) }

              target_names.each { |t| schedules[t] = seq }
            end

            state.with(:execution_schedules, schedules.freeze)
          end
        end
      end
    end
  end
end
