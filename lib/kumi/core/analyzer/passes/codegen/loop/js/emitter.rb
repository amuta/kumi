# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Loop
            module Js
              # Serializes LoopIR into JavaScript. Every opcode maps to a fixed
              # syntax shape; all semantic decisions were made by Loop::Lower.
              class Emitter
                def initialize(registry)
                  @registry = registry
                  @out = []
                  @indent = 0
                end

                def emit(loop_module, schema_digest: nil, streaming: false)
                  reset!

                  loop_module.each_function do |fn|
                    emit_function(fn)
                    emit_streaming_function(fn) if streaming
                  end

                  to_s
                end

                private

                # Decides, per streaming function, which arrays and records can be
                # materialized into caller-owned or module-persistent buffers
                # instead of fresh allocations.
                #
                # - managed arrays: the returned array plus any array built solely to
                #   be pushed into a managed array. They are written by cursor and
                #   truncated, so the previous call's storage is reused.
                # - managed objects: records built solely to be pushed into a managed
                #   array. The previous call's element at the same slot is mutated
                #   instead of allocating a new object.
                # - persisted scratch: intermediate arrays that are only written by
                #   push and read by index, hoisted to module scope. Reads are always
                #   bounded by the current call's loops, so stale tails are inert.
                class StreamPlan
                  attr_reader :target_reg, :managed_arrays, :managed_objects, :persisted_scratch

                  def initialize(fn)
                    @fn = fn
                    instrs = fn.entry_block.instructions

                    producer_idx = {}
                    producer = {}
                    use_count = Hash.new(0)
                    pushes = [] # [instruction index, parent reg, child reg]
                    excluded = {}
                    init_depth = {}
                    pushed_somewhere = {}
                    depth = 0

                    instrs.each_with_index do |instr, idx|
                      if instr.result
                        producer[instr.result] = instr
                        producer_idx[instr.result] = idx
                      end
                      instr.inputs.each { |r| use_count[r] += 1 }
                      case instr.opcode
                      when :array_push
                        pushes << [idx, instr.inputs[0], instr.inputs[1]]
                        pushed_somewhere[instr.inputs[1]] = true
                      when :loop_start
                        excluded[instr.inputs.first] = true
                        depth += 1
                      when :loop_end then depth -= 1
                      when :array_len then excluded[instr.inputs.first] = true
                      when :shift_read then excluded[instr.inputs[0]] = true
                      when :array_init then init_depth[instr.result] = depth
                      end
                    end

                    @target_reg = direct_return_array_reg(fn)
                    @managed_arrays = {} # reg => parent reg (nil for reuse roots)
                    @managed_objects = {} # reg => parent reg
                    @persisted_scratch = {}

                    # Persistence is only safe for arrays created once per call whose
                    # identity never escapes into another array.
                    instrs.each do |instr|
                      next unless instr.opcode == :array_init
                      next if instr.result == @target_reg
                      next if excluded[instr.result] || pushed_somewhere[instr.result]
                      next unless init_depth[instr.result].zero?

                      @persisted_scratch[instr.result] = true
                    end

                    roots = {}
                    roots[@target_reg] = true if @target_reg
                    @persisted_scratch.each_key { |r| roots[r] = true }
                    return if roots.empty?

                    @managed_arrays[@target_reg] = nil if @target_reg
                    reusable = roots.dup
                    loop do
                      changed = false
                      pushes.each do |push_idx, parent, child|
                        next unless reusable.key?(parent)
                        next if reusable.key?(child) || @managed_objects.key?(child)

                        prod = producer[child]
                        next unless prod

                        case prod.opcode
                        when :array_init
                          next if excluded[child]

                          pushes_into = pushes.count { |_, p, _| p == child }
                          pushed = pushes.count { |_, _, c| c == child }
                          next unless pushed == 1 && use_count[child] == pushes_into + 1

                          @managed_arrays[child] = parent
                          reusable[child] = true
                          changed = true
                        when :make_object
                          next unless use_count[child] == 1 && producer_idx[child] + 1 == push_idx
                          next if Array(prod.attributes[:keys]).empty?

                          @managed_objects[child] = parent
                          changed = true
                        end
                      end
                      break unless changed
                    end
                  end

                  def cursor?(reg)
                    @managed_arrays.key?(reg) || @persisted_scratch.key?(reg)
                  end

                  # Typed-array targets can only hold scalars; reject them when the
                  # returned array is filled with records or nested arrays.
                  def record_elements?
                    @managed_objects.value?(@target_reg) || @managed_arrays.value?(@target_reg)
                  end

                  private

                  def direct_return_array_reg(fn)
                    direct = fn.entry_block.instructions.any? do |instr|
                      instr.opcode == :array_init && instr.result == fn.return_reg
                    end
                    direct ? fn.return_reg : nil
                  end
                end

                def reset!
                  @out.clear
                  @indent = 0
                end

                def to_s = @out.join

                def emit_function(fn)
                  write "export function _#{fn.name}(input) {"
                  indented do
                    emit_instructions(fn)
                    write "return #{reg(fn.return_reg)};"
                  end
                  write "}\n"
                end

                def emit_streaming_function(fn)
                  plan = StreamPlan.new(fn)

                  plan.persisted_scratch.each_key do |scratch|
                    write "const #{scratch_name(fn, scratch)} = [];"
                  end

                  write "export function _#{fn.name}_stream(input, target = {}) {"
                  indented do
                    if plan.target_reg
                      write "let __streamTarget = (Array.isArray(target) || ArrayBuffer.isView(target)) ? target : target[\"#{fn.name}\"];"
                      write "let __streamTyped = ArrayBuffer.isView(__streamTarget);"
                      write "if (!Array.isArray(__streamTarget) && !__streamTyped) {"
                      indented do
                        write "__streamTarget = [];"
                        guard = %(target && typeof target === "object" && !ArrayBuffer.isView(target))
                        write %(if (#{guard}) target["#{fn.name}"] = __streamTarget;)
                      end
                      write "}"
                      if plan.record_elements?
                        msg = "_#{fn.name}_stream: output elements are records; pass a plain Array target"
                        write %(if (__streamTyped) throw new TypeError("#{msg}");)
                      end
                    end

                    emit_instructions(fn, plan: plan)

                    if plan.target_reg
                      target_var = reg(plan.target_reg)
                      cursor = cursor_name(plan.target_reg)
                      write "if (__streamTyped) {"
                      indented do
                        msg = %("_#{fn.name}_stream: target holds " + __streamTarget.length + " elements, needed " + #{cursor})
                        write %(if (#{cursor} > __streamTarget.length) throw new RangeError(#{msg});)
                      end
                      write "} else {"
                      indented { write "#{target_var}.length = #{cursor};" }
                      write "}"
                    end
                    guard = %(target && typeof target === "object" && !Array.isArray(target) && !ArrayBuffer.isView(target))
                    write %(if (#{guard}) target["#{fn.name}"] = #{reg(fn.return_reg)};)
                    write "return #{reg(fn.return_reg)};"
                  end
                  write "}\n"
                end

                def emit_instructions(fn, plan: nil)
                  @loop_depth = 0
                  fn.entry_block.instructions.each do |instr|
                    emit_instruction(instr, fn: fn, plan: plan)
                  end
                end

                def emit_instruction(instr, fn: nil, plan: nil)
                  case instr.opcode
                  when :constant
                    write "let #{reg(instr.result)} = #{format_literal(instr.attributes[:value])};"
                  when :load_input
                    key = instr.attributes[:key]
                    write "let #{reg(instr.result)} = input[\"#{key}\"];"
                    if plan&.target_reg && @loop_depth.zero?
                      msg = %(_#{fn.name}_stream: target aliases input \\"#{key}\\"; double-buffer feedback loops)
                      write %(if (#{reg(instr.result)} === __streamTarget) throw new TypeError("#{msg}");)
                    end
                  when :load_field
                    field = instr.attributes[:field]
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)}[\"#{field}\"];"
                  when :kernel_call
                    args = instr.inputs.map { reg(_1) }
                    write "let #{reg(instr.result)} = #{kernel_expr(instr.attributes[:fn], args)};"
                  when :select
                    cond, on_true, on_false = instr.inputs.map { reg(_1) }
                    write "let #{reg(instr.result)} = #{cond} ? #{on_true} : #{on_false};"
                  when :make_object
                    emit_make_object(instr, plan)
                  when :ref
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)};"
                  when :loop_start
                    source = reg(instr.inputs.first)
                    elem = reg(instr.result)
                    idx = reg(instr.attributes[:index])
                    write "for (let #{idx} = 0; #{idx} < #{source}.length; #{idx}++) {"
                    @indent += 1
                    @loop_depth += 1
                    write "let #{elem} = #{source}[#{idx}];"
                  when :loop_end
                    @indent -= 1
                    @loop_depth -= 1
                    write "}"
                  when :array_init
                    emit_array_init(instr, fn, plan)
                  when :array_push
                    emit_array_push(instr, plan)
                  when :array_len
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)}.length;"
                  when :index_read
                    write "let #{reg(instr.result)} = #{reg(instr.inputs[0])}[#{reg(instr.inputs[1])}];"
                  when :shift_read
                    emit_shift_read(instr)
                  when :shift_in_bounds
                    index, length = instr.inputs.map { reg(_1) }
                    out = reg(instr.result)
                    offset = instr.attributes[:offset]
                    write "let #{out}_j = #{index} - (#{offset});"
                    write "let #{out} = #{out}_j >= 0 && #{out}_j < #{length};"
                  when :acc_init
                    init = instr.attributes[:nil_init] ? "null" : format_literal(instr.attributes[:init])
                    write "let #{reg(instr.result)} = #{init};"
                  when :acc_step
                    emit_acc_step(instr)
                  when :acc_load
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)};"
                  else
                    raise "Loop JS codegen does not support #{instr.opcode.inspect}"
                  end
                end

                def emit_array_init(instr, fn, plan)
                  out = reg(instr.result)
                  if plan.nil? || !plan.cursor?(instr.result)
                    write "let #{out} = [];"
                    return
                  end

                  if instr.result == plan.target_reg
                    write "let #{out} = __streamTarget;"
                  elsif (parent = plan.managed_arrays[instr.result])
                    write "let #{out} = #{reg(parent)}[#{cursor_name(parent)}];"
                    write "if (!Array.isArray(#{out})) #{out} = [];"
                  else
                    write "let #{out} = #{scratch_name(fn, instr.result)};"
                  end
                  write "let #{cursor_name(instr.result)} = 0;"
                end

                def emit_array_push(instr, plan)
                  parent, child = instr.inputs
                  unless plan&.cursor?(parent)
                    write "#{reg(parent)}.push(#{reg(child)});"
                    return
                  end

                  write "#{reg(child)}.length = #{cursor_name(child)};" if plan.managed_arrays.key?(child)
                  write "#{reg(parent)}[#{cursor_name(parent)}++] = #{reg(child)};"
                end

                def emit_make_object(instr, plan)
                  keys = Array(instr.attributes[:keys])
                  values = instr.inputs.map { reg(_1) }
                  parent = plan&.managed_objects&.[](instr.result)
                  unless parent
                    write "let #{reg(instr.result)} = #{format_object(keys, values)};"
                    return
                  end

                  out = reg(instr.result)
                  write "let #{out} = #{reg(parent)}[#{cursor_name(parent)}];"
                  if tuple_keys?(keys)
                    write "if (!Array.isArray(#{out})) #{out} = new Array(#{keys.size}); else #{out}.length = #{keys.size};"
                    values.each_with_index { |v, i| write "#{out}[#{i}] = #{v};" }
                  else
                    write "if (#{out} === null || typeof #{out} !== \"object\" || Array.isArray(#{out})) #{out} = {};"
                    keys.zip(values).each { |k, v| write "#{out}[\"#{k}\"] = #{v};" }
                  end
                end

                def cursor_name(sym)
                  "__c#{reg(sym)}"
                end

                def scratch_name(fn, sym)
                  "__s_#{fn.name}_#{reg(sym)}"
                end

                def emit_shift_read(instr)
                  array, index, length = instr.inputs.map { reg(_1) }
                  out = reg(instr.result)
                  offset = instr.attributes[:offset]

                  case instr.attributes[:policy]
                  when :wrap
                    write "let #{out} = #{array}[(((#{index} - (#{offset})) % #{length}) + #{length}) % #{length}];"
                  when :clamp
                    write "let #{out} = #{array}[Math.min(Math.max(#{index} - (#{offset}), 0), #{length} - 1)];"
                  else
                    raise "Loop JS codegen does not support shift policy #{instr.attributes[:policy].inspect}"
                  end
                end

                def emit_acc_step(instr)
                  acc = reg(instr.inputs[0])
                  value = reg(instr.inputs[1])
                  kernel = @registry.kernel_for(instr.attributes[:fn], target: :javascript)
                  template = kernel.inline
                  raise "Missing inline for #{instr.attributes[:fn]}" if template.nil? || template.strip.empty?

                  step = template.strip.gsub("$0", acc).gsub("$1", value)
                  write "#{acc} #{step};"
                end

                def kernel_expr(fn_id, args)
                  kernel = @registry.kernel_for(fn_id, target: :javascript)
                  inline = kernel.inline
                  raise "Missing inline kernel for #{fn_id}" if inline.nil? || inline.strip.empty?

                  apply_inline(inline, args)
                end

                def apply_inline(template, args)
                  expr = template.strip
                  expr = expr.sub(/^=\s*/, "")
                  args.each_with_index { |arg, idx| expr = expr.gsub("$#{idx}", arg) }
                  expr
                end

                def write(line)
                  @out << ("  " * @indent) << line << "\n"
                end

                def indented
                  @indent += 1
                  yield
                  @indent -= 1
                end

                def reg(sym)
                  return "null" unless sym

                  name = sym.to_s
                  return "t#{name[1..]}" if name.start_with?("v") && name[1..].to_i.to_s == name[1..]

                  name
                end

                def format_literal(value)
                  case value
                  when nil then "null"
                  when Symbol then value.to_s.inspect
                  else value.inspect
                  end
                end

                def format_object(keys, values)
                  return "[]" if keys.empty?

                  if tuple_keys?(keys)
                    "[#{values.join(', ')}]"
                  else
                    pairs = keys.zip(values).map { |k, v| "\"#{k}\": #{v}" }
                    "{ #{pairs.join(', ')} }"
                  end
                end

                def tuple_keys?(keys)
                  return false if keys.empty?

                  keys = keys.map(&:to_s)
                  return false unless keys.all? { |k| k.match?(/^_\d+$/) }

                  expected = (0...keys.size).map { |i| "_#{i}" }
                  keys == expected
                end
              end
            end
          end
        end
      end
    end
  end
end
