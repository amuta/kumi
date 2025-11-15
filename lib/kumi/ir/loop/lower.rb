# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      class Lower
        attr_reader :df_module, :context

        def initialize(df_module:, context: {})
          @df_module = df_module
          @context = context
        end

        def call
          loop_module = Loop::Module.new(name: df_module.name)
          df_module.each_function do |df_function|
            loop_function = Loop::Function.new(
              name: df_function.name,
              blocks: [Base::Block.new(name: :entry)]
            )
            loop_module.add_function(loop_function)
            lower_function(df_function, builder_for(loop_module, loop_function))
          end
          loop_module
        end

        private

        def builder_for(loop_module, loop_function)
          Loop::Builder.new(ir_module: loop_module, function: loop_function)
        end

        def plan_index
          @plan_index ||= PlanIndex.new(context[:precomputed_plan_by_fqn] || {})
        end

        def lower_function(df_function, builder)
          lowerer = FunctionLowerer.new(
            builder:,
            plan_index: plan_index,
            registry: context[:registry]
          )
          lowerer.lower(df_function)
        end

        # --- support classes ---

        class PlanIndex
          attr_reader :raw

          def initialize(raw)
            @raw = raw || {}
          end

          def fetch(plan_ref)
            return nil unless plan_ref

            raw.fetch(plan_ref.to_s, nil)
          end
        end

        class Env
          Frame = Struct.new(:axis, :element, :index, :collection, :instructions, :after_instructions, keyword_init: true) do
            def initialize(axis: nil, element: nil, index: nil, collection: nil, instructions: [], after_instructions: [])
              super
              self.axis = axis&.to_sym
              self.instructions ||= []
              self.after_instructions ||= []
            end
          end

          def initialize
            @frames = [Frame.new]
          end

          def root
            @frames.first
          end

          def depth
            @frames.length - 1
          end

          def axes
            @frames.map(&:axis).compact
          end

          def push(frame)
            @frames << Frame.new(**frame)
          end

          def pop
            raise "cannot pop root frame" if @frames.length <= 1

            @frames.pop
          end

          def current_frame
            @frames.last
          end

          def element_for(axis)
            frame_for(axis)&.element
          end

          def frame_for(axis)
            target = axis&.to_sym
            @frames.reverse.find { |frame| frame.axis == target }
          end
        end

        class FunctionLowerer
          InstructionSpec = Struct.new(:builder_method, :args, keyword_init: true)

          attr_reader :builder, :plan_index, :registry, :env, :value_regs

          def initialize(builder:, plan_index:, registry:)
            @builder = builder
            @plan_index = plan_index
            @registry = registry
            @env = Env.new
            @value_regs = {}
            @plan_ref_by_result = {}
            @plan_regs = {}
            @loop_counter = 0
          end

          def lower(df_function)
            df_function.entry_block.each do |instr|
              plan_ref = plan_ref_for_instr(instr)
              target_axes = axes_for(instr)
              ensure_context_for_axes(target_axes, plan_ref)

              if instr.opcode == :reduce
                lower_reduce(instr, plan_ref)
              else
                dispatch_instruction(instr)
              end

            end

            close_loops_to_depth(0)

            last_result = df_function.entry_block.instructions.last&.result
            emit(:yield, values: [fetch_reg(last_result)], metadata: {}) if last_result

            linearize_frame(env.root)
          end

          private

          def fetch_reg(name)
            return nil if name.nil?

            value_regs[name]
          end

          def record(instr, reg)
            value_regs[instr.result] = reg if instr.result
          end

          def record_plan_ref(instr, reg)
            plan_ref = instr.attributes[:plan_ref]
            return unless plan_ref

            @plan_ref_by_result[instr.result] = plan_ref
            @plan_regs[plan_ref.to_s] = reg
          end

          def inherit_plan_ref(instr, from_inputs:)
            plan_ref = from_inputs.map { |input| value_plan_ref(input) }.compact.first
            return unless plan_ref && instr.result

            @plan_ref_by_result[instr.result] = plan_ref
          end

          def value_plan_ref(value)
            @plan_ref_by_result[value]
          end

          def dispatch_instruction(instr)
            case instr.opcode
            when :constant
              reg = emit(:constant, result: instr.result, value: instr.attributes[:value], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata)
              record(instr, reg)
            when :load_input
              reg = emit(:load_input,
                result: instr.result,
                key: instr.attributes[:key],
                plan_ref: instr.attributes[:plan_ref],
                axes: instr.axes,
                dtype: instr.dtype,
                chain: instr.attributes[:chain],
                metadata: instr.metadata
              )
              record(instr, reg)
              record_plan_ref(instr, reg)
            when :load_field
              reg = scalar_value_for_plan(instr) ||
                    emit(:load_field,
                      result: instr.result,
                      object: fetch_reg(instr.inputs.first),
                      field: instr.attributes[:field],
                      plan_ref: instr.attributes[:plan_ref],
                      axes: instr.axes,
                      dtype: instr.dtype,
                      metadata: instr.metadata
                    )
              record(instr, reg)
              record_plan_ref(instr, reg)
            when :map
              reg = emit(:map,
                result: instr.result,
                fn: instr.attributes[:fn],
                args: instr.inputs.map { fetch_reg(_1) },
                axes: instr.axes,
                dtype: instr.dtype,
                metadata: instr.metadata
              )
              record(instr, reg)
              inherit_plan_ref(instr, from_inputs: instr.inputs)
            when :select
              reg = emit(:select,
                result: instr.result,
                cond: fetch_reg(instr.inputs[0]),
                on_true: fetch_reg(instr.inputs[1]),
                on_false: fetch_reg(instr.inputs[2]),
                axes: instr.axes,
                dtype: instr.dtype,
                metadata: instr.metadata
              )
              record(instr, reg)
              inherit_plan_ref(instr, from_inputs: instr.inputs)
            when :axis_shift
              reg = emit(:axis_shift, result: instr.result, source: fetch_reg(instr.inputs.first), axis: instr.attributes[:axis], offset: instr.attributes[:offset], policy: instr.attributes[:policy], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata)
              record(instr, reg)
              inherit_plan_ref(instr, from_inputs: instr.inputs)
            when :axis_broadcast
              reg = emit(:axis_broadcast, result: instr.result, value: fetch_reg(instr.inputs.first), from_axes: instr.attributes[:from_axes], to_axes: instr.attributes[:to_axes], dtype: instr.dtype, metadata: instr.metadata)
              record(instr, reg)
              inherit_plan_ref(instr, from_inputs: instr.inputs)
            when :array_build
              reg = emit(:array_build, result: instr.result, elements: instr.inputs.map { fetch_reg(_1) }, axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata)
              record(instr, reg)
            when :array_get
              reg = emit(:array_get, result: instr.result, array: fetch_reg(instr.inputs[0]), index: fetch_reg(instr.inputs[1]), axes: instr.axes, dtype: instr.dtype, oob: instr.attributes[:oob], metadata: instr.metadata)
              record(instr, reg)
            when :array_len
              reg = emit(:array_len, result: instr.result, array: fetch_reg(instr.inputs.first), axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata)
              record(instr, reg)
            when :axis_index
              record(instr, emit(:axis_index, result: instr.result, axis: instr.attributes[:axis], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
            when :fold
              reg = emit(:fold, result: instr.result, fn: instr.attributes[:fn], arg: fetch_reg(instr.inputs.first), axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata)
              record(instr, reg)
              inherit_plan_ref(instr, from_inputs: instr.inputs)
            when :decl_ref
              record(instr, emit(:decl_ref, result: instr.result, name: instr.attributes[:name], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
            when :import_call
              record(instr, emit(:import_call, result: instr.result, fn_name: instr.attributes[:fn_name], source_module: instr.attributes[:source_module], args: instr.inputs, mapping_keys: instr.attributes[:mapping_keys], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
            when :make_object
              record(instr, emit(:make_object, result: instr.result, keys: instr.attributes[:keys], values: instr.inputs, axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
            when :make_tuple
              record(instr, emit(:make_tuple, result: instr.result, elements: instr.inputs, axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
            when :tuple_get
              record(instr, emit(:tuple_get, result: instr.result, tuple: instr.inputs.first, index: instr.attributes[:index], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
            else
              raise NotImplementedError, "Loop lowering does not handle opcode #{instr.opcode.inspect}"
            end
          end

          def lower_reduce(instr, _plan_ref)
            accumulator = :"#{instr.result}_acc"
            result_axes = Array(instr.axes).map(&:to_sym)
            reduce_axes = Array(instr.attributes[:over_axes]).map(&:to_sym)
            parent_frame = result_axes.empty? ? env.root : env.frame_for(result_axes.last)
            parent_frame ||= env.root

            if reduce_axes.empty?
              emit(:declare_accumulator, frame: parent_frame, result: accumulator, fn: instr.attributes[:fn], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata)
              emit(:accumulate, frame: parent_frame, accumulator:, value: fetch_reg(instr.inputs.first), metadata: instr.metadata)
              record(instr, emit(:load_accumulator, frame: parent_frame, result: instr.result, accumulator:, axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
              return
            end

            emit(:declare_accumulator, frame: parent_frame, result: accumulator, fn: instr.attributes[:fn], axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata)
            emit(:accumulate, accumulator:, value: fetch_reg(instr.inputs.first), metadata: instr.metadata)
            owner_axis = reduce_axes.first
            owner_frame = env.frame_for(owner_axis) || parent_frame
            record(instr, emit_after(owner_frame, :load_accumulator, result: instr.result, accumulator:, axes: instr.axes, dtype: instr.dtype, metadata: instr.metadata))
          end

          def ensure_context_for_axes(target_axes, plan_ref)
            normalized_axes = Array(target_axes).map(&:to_sym)
            lcp = longest_common_prefix(env.axes, normalized_axes)
            close_loops_to_depth(lcp.length)

            normalized_axes.each_with_index do |axis, idx|
              next if env.axes[idx] == axis

              open_axis(plan_ref, axis)
            end
          end

          def plan_ref_for_instr(instr)
            instr.attributes[:plan_ref] ||
              instr.inputs.map { value_plan_ref(_1) }.compact.first ||
              (instr.result && @plan_ref_by_result[instr.result])
          end

          def close_loops_to_depth(depth)
            while env.depth > depth
              frame = env.pop
              parent = env.current_frame
              parent.instructions << frame
              frame.after_instructions.each do |after_instr|
                parent.instructions << after_instr
              end
            end
          end

          def open_axis(plan_ref, axis)
            return unless plan_ref

            plan = plan_index.fetch(plan_ref)
            return unless plan

            li = plan[:axis_to_loop][axis]
            return unless li

            collection = collection_register_for(plan, li)
            return unless collection

            element_reg = next_temp(:"#{axis}_el")
            index_reg = next_temp(:"#{axis}_idx")
            env.push(axis:, element: element_reg, index: index_reg, collection:)
          end

          def collection_register_for(plan, loop_idx)
            if env.depth.zero?
              path = plan[:head_path_by_loop][loop_idx]
              return nil unless path

              ref = plan_ref_from_path(path)
              return nil unless ref

              return @plan_regs[ref]
            end

            prev_axis = env.axes.last
            prev_li = plan[:axis_to_loop][prev_axis]
            keys = plan[:between_loops][[prev_li, loop_idx]] || []
            base = env.element_for(prev_axis)
            return nil unless base
            return base if keys.empty?

            nil
          end

          def plan_ref_from_path(path)
            parts = []
            path.each do |kind, key|
              case kind
              when :input, :field
                parts << key.to_s
              end
            end
            return nil if parts.empty?

            parts.join(".")
          end

          def next_temp(prefix)
            @temp_counter ||= Hash.new(0)
            @temp_counter[prefix] += 1
            :"#{prefix}_#{@temp_counter[prefix]}"
          end

          def next_loop_id
            @loop_counter += 1
            :"L#{@loop_counter}"
          end

          def longest_common_prefix(a, b)
            prefix = []
            a.each_with_index do |axis, idx|
              break if idx >= b.length
              break unless axis == b[idx]

              prefix << axis
            end
            prefix
          end

          def axes_for(instr)
            axes = Array(instr.axes).map(&:to_sym)
            if instr.opcode == :reduce
              axes += Array(instr.attributes[:over_axes]).map(&:to_sym)
            end
            axes
          end

          def scalar_value_for_plan(instr)
            plan_ref = instr.attributes[:plan_ref]
            plan = plan_index.fetch(plan_ref)
            return nil unless plan && plan[:loop_axes].any?

            last_axis = plan[:loop_axes].last
            base = env.element_for(last_axis)
            return nil unless base

            reg = base
            plan[:tail_keys_after_last_loop].each do |field|
              reg = emit(:load_field,
                result: next_temp(field),
                object: reg,
                field: field,
                plan_ref: plan_ref,
                axes: instr.axes,
                dtype: instr.dtype,
                metadata: instr.metadata
              )
            end

            reg
          end

          def emit(builder_method, frame: env.current_frame, **args)
            target = frame || env.current_frame
            target.instructions << InstructionSpec.new(builder_method:, args: args)
            args[:result]
          end

          def emit_after(frame, builder_method, **args)
            target = frame || env.root
            spec = InstructionSpec.new(builder_method:, args: args)
            if target.axis.nil?
              target.instructions << spec
            else
              target.after_instructions << spec
            end
            args[:result]
          end

          def linearize_frame(frame)
            frame.instructions.each do |entry|
              case entry
              when InstructionSpec
                builder.public_send(entry.builder_method, **entry.args)
              when Env::Frame
                emit_loop_frame(entry)
              else
                raise ArgumentError, "Unsupported frame entry #{entry.inspect}"
              end
            end
          end

          def emit_loop_frame(frame)
            loop_id = next_loop_id
            builder.loop_start(axis: frame.axis, collection: frame.collection, element: frame.element, index: frame.index, loop_id:, metadata: {})
            linearize_frame(frame)
            builder.loop_end(loop_id:, metadata: {})
          end
        end
      end
    end
  end
end
