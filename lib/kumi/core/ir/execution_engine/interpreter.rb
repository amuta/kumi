# frozen_string_literal: true

module Kumi
  module Core
    module IR
      module ExecutionEngine
        # Interpreter for IR modules - thin layer that delegates to combinators
        module Interpreter
          PRODUCES_SLOT = %i[const load_input ref array map reduce lift align_to switch].freeze
          NON_PRODUCERS = %i[guard_push guard_pop assign store].freeze
          EMPTY_ARY = [].freeze

          def self.run(schedule, input:, runtime:, accessors:, registry:)
            # Validate registry is properly initialized
            raise ArgumentError, "Registry cannot be nil" if registry.nil?
            raise ArgumentError, "Registry must be a Hash, got #{registry.class}" unless registry.is_a?(Hash)

            # --- PROFILER: init per run (but not in persistent mode) ---
            if Profiler.enabled?
              schema_name = runtime[:schema_name] || "UnknownSchema"
              # In persistent mode, just update schema name without full reset
              Profiler.set_schema_name(schema_name)
            end

            outputs = {}
            target = runtime[:target]
            guard_stack = [true]

            # Caches live in runtime (engine frame), not input
            declaration_cache = runtime[:declaration_cache]

            # Choose declarations to execute - prefer explicit schedule if present
            # decls_to_run = runtime[:decls_to_run] || ir_module.decls

            schedule.each do |decl|
              slots = []
              guard_stack = [true] # reset per decl

              decl.ops.each_with_index do |op, op_index|
                t0 = Profiler.enabled? ? Profiler.t0 : nil
                cpu_t0 = Profiler.enabled? ? Profiler.cpu_t0 : nil
                rows_touched = nil
                if ENV["ASSERT_VM_SLOTS"] == "1"
                  expected = op_index
                  unless slots.length == expected
                    raise "slot drift: have=#{slots.length} expect=#{expected} at #{decl.name}@op#{op_index} #{op.tag}"
                  end
                end

                case op.tag
                when :guard_push
                  cond_slot = op.attrs[:cond_slot]
                  raise "guard_push: cond slot OOB" if cond_slot >= slots.length

                  c = slots[cond_slot]

                  guard_stack << case c[:k]
                                 when :scalar
                                   guard_stack.last && !!c[:v] # same as today
                                 when :vec
                                   # vector mask: push the mask value itself; truthiness handled inside ops
                                   c
                                 else
                                   false
                                 end
                  slots << nil # keep slot_id == op_index
                  if t0
                    Profiler.record!(decl: decl.name, idx: op_index, tag: op.tag, op: op, t0: t0, cpu_t0: cpu_t0, rows: 0,
                                     note: "enter")
                  end
                  next

                when :guard_pop
                  guard_stack.pop
                  slots << nil
                  Profiler.record!(decl: decl.name, idx: op_index, tag: op.tag, op: op, t0: t0, cpu_t0: cpu_t0, rows: 0, note: "exit") if t0
                  next
                end

                # Skip body when guarded off, but keep indices aligned
                unless guard_stack.last
                  slots << nil if PRODUCES_SLOT.include?(op.tag) || NON_PRODUCERS.include?(op.tag)
                  if t0
                    Profiler.record!(decl: decl.name, idx: op_index, tag: op.tag, op: op, t0: t0, cpu_t0: cpu_t0, rows: 0,
                                     note: "skipped")
                  end
                  next
                end

                case op.tag

                when :const
                  result = Values.scalar(op.attrs[:value])
                  slots << result
                  Profiler.record!(decl: decl.name, idx: op_index, tag: :const, op: op, t0: t0, cpu_t0: cpu_t0, rows: 1) if t0

                when :load_input
                  plan_id = op.attrs[:plan_id]
                  scope = op.attrs[:scope] || EMPTY_ARY
                  scalar = op.attrs[:is_scalar]
                  indexed = op.attrs[:has_idx]

                  raw = accessors[plan_id].call(input) # <- memoized by ExecutionEngine

                  slots << if scalar
                             Values.scalar(raw)
                           elsif indexed
                             rows_touched = raw.respond_to?(:size) ? raw.size : raw.count
                             Values.vec(scope, raw.map { |v, idx| { v: v, idx: Array(idx) } }, true)
                           else
                             rows_touched = raw.respond_to?(:size) ? raw.size : raw.count
                             Values.vec(scope, raw.map { |v| { v: v } }, false)
                           end
                  rows_touched ||= 1
                  if t0
                    Profiler.record!(decl: decl.name, idx: op_index, tag: :load_input, op: op, t0: t0, cpu_t0: cpu_t0,
                                     rows: rows_touched, note: "ok")
                  end

                when :ref
                  name = op.attrs[:name]
                  referenced = outputs[name] { raise "unscheduled ref #{name}: producer not executed or dependency analysis failed" }

                  slots << referenced
                  rows_touched = referenced[:k] == :vec ? (referenced[:rows]&.size || 0) : 1
                  if t0
                    Profiler.record!(decl: decl.name, idx: op_index, tag: :ref, op: op, t0: t0, cpu_t0: cpu_t0,
                                     rows: rows_touched, note: hit)
                  end

                when :array
                  parts = op.args.map { |i| slots[i] }
                  if parts.all? { |p| p[:k] == :scalar }
                    slots << Values.scalar(parts.map { |p| p[:v] })
                  else
                    base = parts.find { |p| p[:k] == :vec } or raise "Array literal needs a vec carrier"
                    # Preserve original order: broadcast scalars in-place
                    arg_vecs = parts.map { |p| p[:k] == :scalar ? Combinators.broadcast_scalar(p, base) : p }
                    # All vectors must share scope
                    scopes = arg_vecs.map { |v| v[:scope] }.uniq
                    raise "Cross-scope array literal" unless scopes.size <= 1

                    zipped = Combinators.zip_same_scope(*arg_vecs)
                    rows = zipped[:rows].map do |row|
                      vals = Array(row[:v])
                      row.key?(:idx) ? { v: vals, idx: row[:idx] } : { v: vals }
                    end
                    slots << Values.vec(base[:scope], rows, base[:has_idx])
                  end

                when :map
                  fn_name = op.attrs[:fn]
                  fn_entry = registry[fn_name] or raise "Function #{fn_name} not found in registry"
                  fn = fn_entry.fn

                  # Validate slot indices before accessing
                  op.args.each do |slot_idx|
                    if slot_idx >= slots.length
                      raise "Map operation #{fn_name}: slot index #{slot_idx} out of bounds (slots.length=#{slots.length})"
                    elsif slots[slot_idx].nil?
                      raise "Map operation #{fn_name}: slot #{slot_idx} is nil " \
                            "(available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                    end
                  end

                  args = op.args.map { |slot_idx| slots[slot_idx] }

                  if args.all? { |a| a[:k] == :scalar }
                    scalar_args = args.map { |a| a[:v] }
                    result = fn.call(*scalar_args)
                    slots << Values.scalar(result)
                  else
                    base = args.find { |a| a[:k] == :vec } or raise "Map needs a vec carrier"
                    # Preserve original order: broadcast scalars in-place
                    arg_vecs = args.map { |a| a[:k] == :scalar ? Combinators.broadcast_scalar(a, base) : a }
                    scopes = arg_vecs.map { |v| v[:scope] }.uniq
                    raise "Cross-scope Map without Join" unless scopes.size <= 1

                    zipped = Combinators.zip_same_scope(*arg_vecs)

                    rows = zipped[:rows].map do |row|
                      row_args = Array(row[:v])
                      vr = fn.call(*row_args)
                      row.key?(:idx) ? { v: vr, idx: row[:idx] } : { v: vr }
                    end

                    slots << Values.vec(base[:scope], rows, base[:has_idx])
                  end

                when :switch
                  chosen = op.attrs[:cases].find do |(cond_slot, _)|
                    c = slots[cond_slot]
                    if c[:k] == :scalar
                      !!c[:v]
                    else
                      # TODO: Proper vectorized cascade handling
                      false
                    end
                  end
                  result_slot = chosen ? chosen[1] : op.attrs[:default]

                  slots << slots[result_slot]

                when :store
                  name = op.attrs[:name]
                  src  = op.args[0] or raise "store: missing source slot"

                  result = slots[src]
                  outputs[name] = result
                  # Also store in declaration cache for future ref operations
                  declaration_cache[name] = result

                  # keep slot_id == op_index invariant
                  slots << nil

                  return outputs if target && name == target

                when :reduce
                  fn_entry = registry[op.attrs[:fn]] or raise "Function #{op.attrs[:fn]} not found in registry"
                  fn = fn_entry.fn

                  src = slots[op.args[0]]
                  result_scope = op.attrs[:result_scope]
                  axis         = op.attrs[:axis]

                  if result_scope.empty?
                    # === GLOBAL REDUCE ===
                    # Accept either ravel or indexed.
                    vals = src[:rows].map { |r| r[:v] }
                    slots << Values.scalar(fn.call(vals))
                  else
                    group_len = result_scope.length

                    # Preserve stable source order so zips with other @result_scope vecs line up.
                    groups = {}         # { key(Array<Integer>) => Array<value> }
                    order  = []         # Array<key> in first-seen order

                    src[:rows].each do |row|
                      key = Array(row[:idx]).first(group_len)
                      unless groups.key?(key)
                        groups[key] = []
                        order << key
                      end
                      groups[key] << row[:v]
                    end

                    out_rows = order.map { |key| { v: fn.call(groups[key]), idx: key } }

                    slots << Values.vec(result_scope, out_rows, true)
                  end

                when :lift
                  src_slot = op.args[0]

                  v = slots[src_slot]
                  to_scope = op.attrs[:to_scope] || EMPTY_ARY
                  depth    = [to_scope.length, v[:rank] || v[:rows].first&.dig(:idx)&.length || 0].min
                  slots << Values.scalar(Combinators.group_rows(v[:rows], depth))

                when :align_to
                  tgt = slots[op.args[0]]
                  src = slots[op.args[1]]

                  to_scope = op.attrs[:to_scope] || EMPTY_ARY
                  require_unique = op.attrs[:require_unique] || false
                  on_missing = op.attrs[:on_missing] || :error

                  aligned = Combinators.align_to(tgt, src, to_scope: to_scope,
                                                           require_unique: require_unique,
                                                           on_missing: on_missing)
                  slots << aligned

                else
                  raise "Unknown operation: #{op.tag}"
                end
              rescue StandardError => e
                op_index = decl.ops.index(op) || "?"
                context_info = []
                context_info << "slots.length=#{slots.length}"
                context_info << "non_nil_slots=#{slots.compact.length}" if slots.any?(&:nil?)
                context_info << "op_attrs=#{op.attrs.inspect}" if op.attrs && !op.attrs.empty?
                context_info << "op_args=#{op.args.inspect}" if op.args && !op.args.empty?

                context_str = context_info.empty? ? "" : " (#{context_info.join(', ')})"
                raise "#{decl.name}@op#{op_index} #{op.tag}#{context_str}: #{e.message}"
              end
            end

            # --- end-of-run summary ---
            Profiler.emit_summary! if Profiler.enabled?
            outputs
          end
        end
      end
    end
  end
end
