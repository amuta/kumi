# frozen_string_literal: true

module Kumi
  module Core
    module IR
      module ExecutionEngine
        # Interpreter for IR modules - thin layer that delegates to combinators
        module Interpreter
          PRODUCES_SLOT = %i[const load_input ref array map reduce lift align_to switch].freeze
          NON_PRODUCERS = %i[guard_push guard_pop assign store].freeze

          def self.build_name_index(ir_module)
            index = {}
            ir_module.decls.each do |decl|
              decl.ops.each do |op|
                next unless op.tag == :store
                name = op.attrs[:name]
                index[name] = decl if name
              end
            end
            index
          end

          def self.run(ir_module, ctx, accessors:, registry:)
            # Validate registry is properly initialized
            raise ArgumentError, "Registry cannot be nil" if registry.nil?
            raise ArgumentError, "Registry must be a Hash, got #{registry.class}" unless registry.is_a?(Hash)

            # --- PROFILER: init per run ---
            Profiler.reset!(meta: { decls: ir_module.decls&.size || 0 }) if Profiler.enabled?

            outputs = {}
            target = ctx[:target]
            guard_stack = [true]
            
            # Always ensure we have a declaration cache - either from caller or new for this VM run
            declaration_cache = ctx[:declaration_cache] || {}

            # Build name index for targeting by stored names
            name_index = ctx[:name_index] || (target ? build_name_index(ir_module) : nil)

            # Choose declarations to execute by stored name (not only decl name)
            decls_to_run = 
              if target
                # Prefer a decl that STORES the target (covers __vec twins)
                d = name_index && name_index[target]
                # Fallback: allow targeting by decl name (legacy behavior)
                d ||= ir_module.decls.find { |dd| dd.name == target }
                raise "Unknown target: #{target}" unless d
                [d]
              else
                ir_module.decls
              end

            decls_to_run.each do |decl|
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
                  Profiler.record!(decl: decl.name, idx: op_index, tag: op.tag, op: op, t0: t0, cpu_t0: cpu_t0, rows: 0, note: "enter") if t0
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
                  Profiler.record!(decl: decl.name, idx: op_index, tag: op.tag, op: op, t0: t0, cpu_t0: cpu_t0, rows: 0, note: "skipped") if t0
                  next
                end

                case op.tag

                when :assign
                  dst = op.attrs[:dst]
                  src = op.attrs[:src]
                  raise "assign: dst/src OOB" if dst >= slots.length || src >= slots.length

                  slots[dst] = slots[src]
                  Profiler.record!(decl: decl.name, idx: op_index, tag: :assign, op: op, t0: t0, cpu_t0: cpu_t0, rows: 1) if t0

                when :const
                  result = Values.scalar(op.attrs[:value])
                  puts "DEBUG Const #{op.attrs[:value].inspect}: result=#{result}" if ENV["DEBUG_VM_ARGS"]
                  slots << result
                  Profiler.record!(decl: decl.name, idx: op_index, tag: :const, op: op, t0: t0, cpu_t0: cpu_t0, rows: 1) if t0

                when :load_input
                  plan_id = op.attrs[:plan_id]
                  scope = op.attrs[:scope] || []
                  scalar = op.attrs[:is_scalar]
                  indexed = op.attrs[:has_idx]

                  # NEW: consult runtime accessor cache
                  acc_cache = ctx[:accessor_cache] || {}
                  input_obj = ctx[:input] || ctx["input"]
                  cache_key = [plan_id, input_obj.object_id]

                  if acc_cache.key?(cache_key)
                    raw = acc_cache[cache_key]
                    hit = true
                  else
                    raw = accessors.fetch(plan_id).call(input_obj)
                    acc_cache[cache_key] = raw
                    hit = false
                  end

                  puts "DEBUG LoadInput plan_id: #{plan_id} raw_values: #{raw.inspect} cache_hit: #{hit}" if ENV["DEBUG_VM_ARGS"]
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
                  cache_note = hit ? "hit:#{plan_id}" : "miss:#{plan_id}"
                  Profiler.record!(decl: decl.name, idx: op_index, tag: :load_input, op: op, t0: t0, cpu_t0: cpu_t0,
                                   rows: rows_touched, note: cache_note) if t0

                when :ref
                  name = op.attrs[:name]
                  
                  if outputs.key?(name)
                    referenced = outputs[name]
                  elsif declaration_cache.key?(name)
                    referenced = declaration_cache[name]
                  else
                    # demand-compute the producing decl up to the store of `name`
                    active = (ctx[:active] ||= {})
                    raise "cycle detected: #{name}" if active[name]
                    active[name] = true
                    
                    subctx = {
                      input: ctx[:input] || ctx["input"],
                      target: name,                         # target is the STORED NAME
                      accessor_cache: ctx[:accessor_cache],
                      declaration_cache: ctx[:declaration_cache],
                      name_index: name_index,               # reuse map
                      active: active
                    }
                    referenced = self.run(ir_module, subctx, accessors: accessors, registry: registry).fetch(name)
                    active.delete(name)
                  end
                  
                  if ENV["DEBUG_VM_ARGS"]
                    puts "DEBUG Ref #{name}: #{referenced[:k] == :scalar ? "scalar(#{referenced[:v].inspect})" : "#{referenced[:k]}(#{referenced[:rows]&.size || 0} rows)"}"
                  end
                  
                  slots << referenced
                  rows_touched = (referenced[:k] == :vec) ? (referenced[:rows]&.size || 0) : 1
                  Profiler.record!(decl: decl.name, idx: op_index, tag: :ref, op: op, t0: t0, cpu_t0: cpu_t0, rows: rows_touched) if t0

                when :array
                  # Validate slot indices before accessing
                  op.args.each do |slot_idx|
                    if slot_idx >= slots.length
                      raise "Array operation: slot index #{slot_idx} out of bounds (slots.length=#{slots.length})"
                    elsif slots[slot_idx].nil?
                      raise "Array operation: slot #{slot_idx} is nil " \
                            "(available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                    end
                  end

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
                  puts "DEBUG Map #{fn_name}: args=#{op.args.inspect}" if ENV["DEBUG_VM_ARGS"]

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
                    puts "DEBUG Scalar call #{fn_name}: args=#{args.map { |a| a[:v] }.inspect}" if ENV["DEBUG_VM_ARGS"]
                    scalar_args = args.map { |a| a[:v] }
                    result = fn.call(*scalar_args)
                    slots << Values.scalar(result)
                  else
                    base = args.find { |a| a[:k] == :vec } or raise "Map needs a vec carrier"
                    puts "DEBUG Vec call #{fn_name}: base=#{base.inspect}" if ENV["DEBUG_VM_ARGS"]
                    # Preserve original order: broadcast scalars in-place
                    arg_vecs = args.map { |a| a[:k] == :scalar ? Combinators.broadcast_scalar(a, base) : a }
                    puts "DEBUG Vec call #{fn_name}: arg_vecs=#{arg_vecs.inspect}" if ENV["DEBUG_VM_ARGS"]
                    scopes = arg_vecs.map { |v| v[:scope] }.uniq
                    puts "DEBUG Vec call #{fn_name}: scopes=#{scopes.inspect}" if ENV["DEBUG_VM_ARGS"]
                    raise "Cross-scope Map without Join" unless scopes.size <= 1

                    zipped = Combinators.zip_same_scope(*arg_vecs)

                    # if ENV["DEBUG_VM_ARGS"] && fn_name == :if
                    #   puts "DEBUG Vec call #{fn_name}: zipped rows:"
                    #   zipped[:rows].each_with_index do |row, i|
                    #     puts "  [#{i}] args=#{Array(row[:v]).inspect}"
                    #   end
                    # end

                    puts "DEBUG Vec call #{fn_name}: zipped rows=#{zipped[:rows].inspect}" if ENV["DEBUG_VM_ARGS"]
                    rows = zipped[:rows].map do |row|
                      row_args = Array(row[:v])
                      vr = fn.call(*row_args)
                      row.key?(:idx) ? { v: vr, idx: row[:idx] } : { v: vr }
                    end
                    puts "DEBUG Vec call #{fn_name}: result rows=#{rows.inspect}" if ENV["DEBUG_VM_ARGS"]

                    slots << Values.vec(base[:scope], rows, base[:has_idx])
                  end

                when :switch
                  chosen = op.attrs[:cases].find do |(cond_slot, _)|
                    if cond_slot >= slots.length
                      raise "Switch operation: condition slot #{cond_slot} out of bounds (slots.length=#{slots.length})"
                    elsif slots[cond_slot].nil?
                      raise "Switch operation: condition slot #{cond_slot} is nil (available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                    end

                    c = slots[cond_slot]
                    if c[:k] == :scalar
                      !!c[:v]
                    else
                      # TODO: Proper vectorized cascade handling
                      false
                    end
                  end
                  result_slot = chosen ? chosen[1] : op.attrs[:default]
                  if result_slot >= slots.length
                    raise "Switch operation: result slot #{result_slot} out of bounds (slots.length=#{slots.length})"
                  elsif slots[result_slot].nil?
                    raise "Switch operation: result slot #{result_slot} is nil (available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                  end

                  slots << slots[result_slot]

                when :store
                  name = op.attrs[:name]
                  src  = op.args[0] or raise "store: missing source slot"
                  if src >= slots.length
                    raise "Store operation '#{name}': source slot #{src} out of bounds (slots.length=#{slots.length})"
                  elsif slots[src].nil?
                    raise "Store operation '#{name}': source slot #{src} is nil (available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                  end

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
                  raise "Reduce expects Vec" unless src[:k] == :vec

                  result_scope = Array(op.attrs[:result_scope] || [])
                  axis         = Array(op.attrs[:axis] || [])

                  if result_scope.empty?
                    # === GLOBAL REDUCE ===
                    # Accept either ravel or indexed.
                    vals = src[:rows].map { |r| r[:v] }
                    slots << Values.scalar(fn.call(vals))
                  else
                    # === GROUPED REDUCE ===
                    # Must have indices to group by prefix keys.
                    unless src[:has_idx]
                      raise "Grouped reduce requires indexed input (got ravel) for #{op.attrs[:fn]} at #{result_scope.inspect}"
                    end

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
                  if src_slot >= slots.length
                    raise "Lift operation: source slot #{src_slot} out of bounds (slots.length=#{slots.length})"
                  elsif slots[src_slot].nil?
                    raise "Lift operation: source slot #{src_slot} is nil (available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                  end

                  v = slots[src_slot]
                  to_scope = op.attrs[:to_scope] || []
                  depth    = [to_scope.length, v[:rank] || v[:rows].first&.dig(:idx)&.length || 0].min
                  slots << Values.scalar(Combinators.group_rows(v[:rows], depth))

                when :align_to
                  tgt_slot = op.args[0]
                  src_slot = op.args[1]

                  if tgt_slot >= slots.length
                    raise "AlignTo operation: target slot #{tgt_slot} out of bounds (slots.length=#{slots.length})"
                  elsif slots[tgt_slot].nil?
                    raise "AlignTo operation: target slot #{tgt_slot} is nil " \
                          "(available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                  end

                  if src_slot >= slots.length
                    raise "AlignTo operation: source slot #{src_slot} out of bounds (slots.length=#{slots.length})"
                  elsif slots[src_slot].nil?
                    raise "AlignTo operation: source slot #{src_slot} is nil " \
                          "(available slots: #{slots.length}, non-nil slots: #{slots.compact.length})"
                  end

                  tgt = slots[tgt_slot]
                  src = slots[src_slot]

                  to_scope = op.attrs[:to_scope] || []
                  require_unique = op.attrs[:require_unique] || false
                  on_missing = op.attrs[:on_missing] || :error

                  aligned = Combinators.align_to(tgt, src, to_scope: to_scope,
                                                           require_unique: require_unique,
                                                           on_missing: on_missing)
                  slots << aligned

                when :join
                  raise NotImplementedError, "Join not implemented yet"

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
