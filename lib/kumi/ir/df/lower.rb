# frozen_string_literal: true

module Kumi
  module IR
    module DF
      class Lower
        NAST = Kumi::Core::NAST

        def initialize(snast_module:, registry:, input_table:)
          @snast_module = snast_module
          @registry = registry
          @input_table = input_table
          @graph = Graph.new(name: snast_module.respond_to?(:name) ? snast_module.name : :anonymous)
          @reg_counter = 0
        end

        def call
          @snast_module.decls.each do |name, decl|
            lower_declaration(name, decl)
          end
          @graph
        end

        private

        def lower_declaration(name, decl)
          function = Function.new(name:, blocks: [Base::Block.new(name: :entry)])
          @graph.add_function(function)
          builder = Builder.new(ir_module: @graph, function: function)
          @memo = {}
          lower_expr(decl.body, builder)
        end

        def lower_expr(node, builder)
          return @memo[node.object_id] if @memo.key?(node.object_id)

          result =
            case node
            when NAST::Const
              emit_constant(node, builder)
            when NAST::InputRef
              emit_input(node, builder)
            when NAST::Call
              emit_call(node, builder)
            when NAST::Select
              emit_select(node, builder)
            when NAST::Reduce
              emit_reduce(node, builder)
            when NAST::Fold
              emit_fold(node, builder)
            when NAST::ImportCall
              emit_import_call(node, builder)
            when NAST::Ref
              emit_decl_ref(node, builder)
            when NAST::Hash
              emit_hash(node, builder)
            when NAST::Tuple
              emit_tuple(node, builder)
            when NAST::IndexRef
              emit_index_ref(node, builder)
            else
              raise NotImplementedError, "DF lowering not yet implemented for #{node.class}"
            end

          @memo[node.object_id] = result
        end

        def emit_constant(node, builder)
          result = next_reg
          builder.constant(result:, value: node.value, axes: axes_of(node), dtype: dtype_of(node), metadata: {})
        end

        def emit_input(node, builder)
          segments = Array(node.path)
          raise "InputRef without path" if segments.empty?

          axes = axes_of(node)
          dtype = dtype_of(node)

          current = builder.load_input(
            result: next_reg,
            key: segments.first,
            chain: node.key_chain,
            axes: axes,
            dtype: dtype,
            metadata: {}
          )

          segments.drop(1).each do |field|
            current = builder.load_field(
              result: next_reg,
              object: current,
              field: field,
              axes: axes,
              dtype: dtype,
              metadata: {}
            )
          end

          current
        end

        def emit_call(node, builder)
          if %i[shift roll].include?(node.fn)
            return emit_axis_shift(node, builder)
          end

          args = []
          node.args.each do |arg_node|
            reg = lower_expr(arg_node, builder)
            reg = align_axes(reg, axes_of(arg_node), axes_of(node), dtype_of(arg_node), builder)
            args << reg
          end
          fn_id = node.meta[:function] || @registry.resolve_function(node.fn)
          result = next_reg
          builder.map(result:, fn: fn_id, args:, axes: axes_of(node), dtype: dtype_of(node), metadata: {})
        end

        def emit_select(node, builder)
          cond = lower_expr(node.cond, builder)
          on_true = lower_expr(node.on_true, builder)
          on_false = lower_expr(node.on_false, builder)
          target_axes = axes_of(node)
          cond = align_axes(cond, axes_of(node.cond), target_axes, dtype_of(node.cond), builder)
          on_true = align_axes(on_true, axes_of(node.on_true), target_axes, dtype_of(node.on_true), builder)
          on_false = align_axes(on_false, axes_of(node.on_false), target_axes, dtype_of(node.on_false), builder)
          result = next_reg
          builder.select(
            result:,
            cond:,
            on_true:,
            on_false:,
            axes: axes_of(node),
            dtype: dtype_of(node),
            metadata: {}
          )
        end

        def emit_reduce(node, builder)
          arg = lower_expr(node.arg, builder)
          fn_id = node.meta[:function] || @registry.resolve_function(node.fn)
          result = next_reg
          builder.reduce(
            result:,
            fn: fn_id,
            arg:,
            axes: axes_of(node),
            over_axes: node.over,
            dtype: dtype_of(node),
            metadata: {}
          )
        end

        def emit_fold(node, builder)
          arg = lower_expr(node.arg, builder)
          arg = align_axes(arg, axes_of(node.arg), axes_of(node), dtype_of(node.arg), builder)
          fn_id = node.meta[:function] || @registry.resolve_function(node.fn)
          out_dtype = fold_result_type(fn_id, dtype_of(node.arg))
          result = next_reg
          builder.fold(
            result:,
            fn: fn_id,
            arg:,
            axes: axes_of(node),
            dtype: out_dtype,
            metadata: {}
          )
        end

        def emit_decl_ref(node, builder)
          result = next_reg
          builder.decl_ref(
            result:,
            name: node.name,
            axes: axes_of(node),
            dtype: dtype_of(node),
            metadata: {}
          )
        end

        def emit_tuple(node, builder)
          elems = node.args.map { lower_expr(_1, builder) }
          result = next_reg
          builder.array_build(
            result:,
            elements: elems,
            axes: axes_of(node),
            dtype: dtype_of(node),
            metadata: {}
          )
        end

        def emit_hash(node, builder)
          keys = []
          vals = []
          node.pairs.each do |pair|
            keys << pair.key
            vals << lower_expr(pair.value, builder)
          end
          result = next_reg
          builder.make_object(
            result:,
            inputs: vals,
            keys: keys,
            axes: axes_of(node),
            dtype: dtype_of(node),
            metadata: {}
          )
        end

        def emit_import_call(node, builder)
          args = node.args.map do |arg|
            reg = lower_expr(arg, builder)
            align_axes(reg, axes_of(arg), axes_of(node), dtype_of(arg), builder)
          end
          result = next_reg
          builder.import_call(
            result:,
            fn_name: node.fn_name,
            source_module: node.source_module,
            args: args,
            mapping_keys: node.input_mapping_keys,
            axes: axes_of(node),
            dtype: dtype_of(node),
            metadata: {}
          )
        end

        def emit_index_ref(node, builder)
          axis = axes_of(node).last or raise "IndexRef without axis"
          result = next_reg
          builder.axis_index(
            result:,
            axis: axis,
            axes: axes_of(node),
            dtype: dtype_of(node),
            metadata: { source: node.input_fqn }
          )
        end

        def emit_axis_shift(node, builder)
          source_node, offset_node = node.args
          raise "shift/roll requires source and offset" unless source_node && offset_node

          offset = literal_offset!(offset_node)
          opts = merge_shift_opts(node)

          source_axes = axes_of(source_node)
          idx = source_axes.length - 1 - opts[:axis_offset]
          raise "shift axis_offset #{opts[:axis_offset]} out of range" if idx.negative?
          axis = source_axes[idx]

          result = next_reg
          builder.axis_shift(
            result:,
            source: align_axes(lower_expr(source_node, builder), axes_of(source_node), axes_of(node), dtype_of(source_node), builder),
            axis: axis,
            offset: offset,
            policy: opts[:policy],
            axes: axes_of(node),
            dtype: dtype_of(node),
            metadata: {}
          )
        end

        def dtype_of(node)
          normalize_dtype(node.meta.dig(:stamp, :dtype))
        end

        def axes_of(node)
          Array(node.meta.dig(:stamp, :axes))
        end

        def normalize_dtype(dtype)
          return nil if dtype.nil?
          return dtype if dtype.is_a?(Kumi::Core::Types::Type)

          Kumi::Core::Types.normalize(dtype)
        end

        def next_reg
          @reg_counter += 1
          "v#{@reg_counter}".to_sym
        end

        def literal_offset!(node)
          val = node.is_a?(NAST::Const) ? node.value : nil
          raise "shift offset must be integer literal" unless val.is_a?(Integer)

          val
        end

        def merge_shift_opts(node)
          defaults = function_options(node.fn)
          opts = call_options(node)
          policy = (opts[:policy] || defaults[:policy] || default_policy_for(node.fn)).to_sym
          axis_offset = Integer(opts[:axis_offset] || defaults[:axis_offset] || 0)
          { policy:, axis_offset: }
        end

        def call_options(node)
          raw = node.opts || {}
          raw = raw[:opts] if raw.respond_to?(:key?) && raw.key?(:opts)
          raw.each_with_object({}) do |(k, v), h|
            key = k.respond_to?(:to_sym) ? k.to_sym : k
            h[key] = v
          end
        end

        def default_policy_for(fn)
          fn == :roll ? :wrap : :zero
        end

        def align_axes(reg, from_axes, to_axes, dtype, builder)
          from_axes = Array(from_axes)
          to_axes = Array(to_axes)
          return reg if from_axes == to_axes
          raise "cannot broadcast #{from_axes.inspect} to #{to_axes.inspect}" unless prefix?(from_axes, to_axes)

          builder.axis_broadcast(
            result: next_reg,
            value: reg,
            from_axes: from_axes,
            to_axes: to_axes,
            dtype: dtype,
            metadata: {}
          )
        end

        def prefix?(lhs, rhs)
          lhs.each_with_index.all? { |ax, idx| rhs[idx] == ax }
        end

        def function_options(fn)
          return {} unless @registry.respond_to?(:function)

          spec = @registry.function(fn) rescue nil
          return {} unless spec

          if spec.respond_to?(:[])
            spec[:options] || {}
          elsif spec.respond_to?(:options)
            spec.options || {}
          else
            {}
          end
        end

        def fold_result_type(fn_id, input_dtype)
          return input_dtype unless @registry.respond_to?(:function)

          spec = @registry.function(fn_id) rescue nil
          return input_dtype unless spec

          rule = spec[:dtype_rule] || (spec.respond_to?(:dtype_rule) ? spec.dtype_rule : nil)
          param_names = spec[:parameter_names] || spec[:parameter_names] || [:arg]
          return input_dtype unless rule

          begin
            if rule.respond_to?(:call)
              named = { param_names.first => input_dtype }
              rule.call(named) || input_dtype
            else
              input_dtype
            end
          rescue StandardError
            input_dtype
          end
        end
      end
    end
  end
end
