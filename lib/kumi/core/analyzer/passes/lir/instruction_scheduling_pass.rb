# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          # InstructionSchedulingPass
          # -------------------------
          # This pass reorders instructions within a block to improve opportunities for
          # other passes, particularly LoopFusionPass. It treats a block of LIR as a
          # graph of atomic items (single instructions or entire loops), builds a
          # dependency graph, and then re-emits the instructions in an optimal order
          # determined by a topological sort.
          class InstructionSchedulingPass < PassBase
            def run(_errors)
              scheduled_module = get_state(:lir_module).transform_values do |decl|
                debug "\n--- Scheduling: Processing declaration: #{decl[:name]} ---"
                { operations: schedule_block(Array(decl[:operations])) }
              end

              state.with(:lir_module, scheduled_module)
            end

            private

            def schedule_block(ops, depth = 0)
              new_ops = []
              i = 0
              while i < ops.length
                ins = ops[i]
                if ins.opcode == :LoopStart
                  end_index = find_matching_loop_end(ops, i)
                  loop_body = ops[(i + 1)...end_index]

                  scheduler = Scheduler.new(self, loop_body, depth + 1)
                  scheduled_body = scheduler.schedule

                  new_ops << ins
                  new_ops.concat(scheduled_body)
                  new_ops << ops[end_index]

                  i = end_index + 1
                else
                  new_ops << ins
                  i += 1
                end
              end
              new_ops
            end

            def find_matching_loop_end(ops, start_index)
              depth = 1
              (start_index + 1...ops.length).each do |i|
                return i if ops[i].opcode == :LoopEnd && (depth -= 1).zero?

                depth += 1 if ops[i].opcode == :LoopStart
              end
              raise "Unbalanced LoopStart at index #{start_index}"
            end

            # --- Main Scheduler Logic ---
            class Scheduler
              Item = Struct.new(:id, :ops, :defs, :uses, keyword_init: true)

              def initialize(pass, ops, depth)
                @pass = pass
                @ops = ops
                @depth = depth
                @prefix = "  " * @depth
              end

              def schedule
                debug "#{@prefix}> Starting instruction scheduling for block of #{@ops.size} instructions."
                items = group_into_atomic_items(@ops)
                return @ops if items.size <= 1

                graph, in_degree = build_dependency_graph(items)
                debug_graph(items, graph)

                sorted_item_ids = topological_sort(graph, in_degree, items.map(&:id))
                debug "#{@prefix}  - Final schedule order: #{sorted_item_ids.join(' -> ')}"

                items_by_id = items.to_h { |item| [item.id, item] }
                sorted_item_ids.flat_map { |id| items_by_id[id].ops }
              end

              private

              def group_into_atomic_items(ops)
                items = []
                i = 0
                while i < ops.length
                  ins = ops[i]
                  if ins.opcode == :LoopStart
                    end_index = find_matching_loop_end(ops, i)
                    loop_ops = ops[i..end_index]
                    items << Item.new(id: "Loop(#{ins.attributes[:id]})", ops: loop_ops)
                    i = end_index
                  else
                    id_val = ins.result_register || "op_#{ins.object_id}"
                    items << Item.new(id: "Inst(#{id_val})", ops: [ins])
                  end
                  i += 1
                end
                items.each { |item| analyze_item_defs_and_uses(item) }
                items
              end

              def find_matching_loop_end(ops, start_index)
                depth = 1; (start_index + 1...ops.length).each do |i|
                  return i if ops[i].opcode == :LoopEnd && (depth -= 1).zero?

                  depth += 1 if ops[i].opcode == :LoopStart
                end
                raise "Unbalanced LoopStart at index #{start_index}"
              end

              def build_dependency_graph(items)
                graph = Hash.new { |h, k| h[k] = [] }
                in_degree = items.to_h { |item| [item.id, 0] }

                items.each do |item_a|
                  items.each do |item_b|
                    next if item_a.id == item_b.id

                    if (item_a.defs & item_b.uses).any?
                      graph[item_a.id] << item_b.id
                      in_degree[item_b.id] += 1
                    end
                  end
                end
                [graph, in_degree]
              end

              def topological_sort(graph, in_degree, all_ids)
                queue = all_ids.select { |id| in_degree[id].zero? }
                sorted = []
                while (id = queue.shift)
                  sorted << id
                  (graph[id] || []).each do |neighbor_id|
                    in_degree[neighbor_id] -= 1
                    queue << neighbor_id if in_degree[neighbor_id].zero?
                  end
                end
                raise "Cyclic dependency detected in LIR" if sorted.length != all_ids.length

                sorted
              end

              # --- FIX: Rewritten analysis logic to correctly calculate dependencies ---
              def analyze_item_defs_and_uses(item)
                internal_defs = Set.new
                all_uses = Set.new

                item.ops.each do |op|
                  # Collect all registers defined within this item's scope.
                  internal_defs.add(op.result_register) if op.result_register
                  if op.opcode == :LoopStart
                    internal_defs.add(op.attributes[:as_element])
                    internal_defs.add(op.attributes[:as_index])
                  end

                  # Collect all registers used as inputs.
                  all_uses.merge(Array(op.inputs))
                end

                # The item's public definitions are all its internal definitions.
                item.defs = internal_defs

                # The item's external uses are all registers used that are NOT
                # defined within the item itself. This is the key insight.
                item.uses = all_uses - internal_defs
              end
              # --- END OF FIX ---

              def debug(...)
                @pass.debug(...)
              end

              def debug_graph(items, graph)
                debug "#{@prefix}  - Dependency Graph of #{items.size} items:"
                items.each do |item|
                  uses = item.uses.to_a.sort.join(", ")
                  defs = item.defs.to_a.sort.join(", ")
                  deps = graph[item.id]&.join(", ") || ""
                  debug "#{@prefix}    - #{item.id} (defs: {#{defs}}, uses: {#{uses}}) -> [#{deps}]"
                end
              end
            end
          end
        end
      end
    end
  end
end
