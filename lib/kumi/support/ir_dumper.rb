# frozen_string_literal: true
module Kumi
  module Support
    module IRDump
      Options = Struct.new(
        :show_inputs, :annotators, :width, :color, :indent, :max_array_elems,
        keyword_init: true
      )

      class Context
        attr_reader :ir, :state, :opts
        def initialize(ir_module, analysis_state, opts)
          @ir = ir_module
          @state = analysis_state || {}
          @opts = merge_opts(default_opts, opts || {})
        end

        def default_opts
          Options.new(
            show_inputs: true,
            annotators: %i[plans types op_counts vec_twins],
            width: 100, color: !!ENV["DUMP_COLOR"], indent: 2,
            max_array_elems: 8
          )
        end
        
        private
        
        def merge_opts(defaults, overrides)
          # Struct doesn't have merge, so we need to do this manually
          Options.new(
            show_inputs: overrides.fetch(:show_inputs, defaults.show_inputs),
            annotators: overrides.fetch(:annotators, defaults.annotators),
            width: overrides.fetch(:width, defaults.width),
            color: overrides.fetch(:color, defaults.color),
            indent: overrides.fetch(:indent, defaults.indent),
            max_array_elems: overrides.fetch(:max_array_elems, defaults.max_array_elems)
          )
        end
      end

      module_function

      def dump(ir_module, analysis_state: nil, to: $stdout, format: :text, opts: {})
        ctx = Context.new(ir_module, analysis_state, opts)
        case format
        when :text then to.puts(to_text(ctx))
        when :json then to.puts(to_json(ctx))
        else raise ArgumentError, "unknown format: #{format.inspect}"
        end
        nil
      end

      def to_text(ctx)
        lines = []
        if ctx.state.any? && ctx.opts.annotators.include?(:plans)
          lines << "=" * 60 << "ANALYSIS STATE" << "=" * 60
          lines << format_plans(ctx)
          lines << ""
        end

        if ctx.opts.show_inputs
          lines << "=" * 60 << "INPUT METADATA" << "=" * 60
          ctx.ir.inputs.each { |name, meta| lines << format_input(name, meta) }
          lines << ""
        end

        lines << "=" * 60 << "IR DECLARATIONS (#{ctx.ir.decls.size})" << "=" * 60
        ctx.ir.decls.each_with_index do |decl, i|
          lines << ""
          lines << format_decl_header(ctx, decl, i)
          decl.ops.each_with_index { |op, j| lines << (" " * 4) + format_op(ctx, decl, op, j) }
        end

        lines.join("\n")
      end

      def to_json(ctx)
        # machine-readable dump that tools can diff/parse
        require "json"
        {
          inputs: ctx.ir.inputs,
          decls: ctx.ir.decls.map { |d|
            {
              name: d.name, kind: d.kind, shape: d.shape,
              ops: d.ops.each_with_index.map { |op, i|
                { idx: i, tag: op.tag, attrs: op.attrs, args: op.args }
              }
            }
          },
          analysis: compact_state(ctx)
        }.to_json
      end

      # ------------------------
      # Formatting helpers
      # ------------------------

      def format_input(name, meta)
        type = meta[:type] ? " : #{meta[:type]}" : ""
        dom  = meta[:domain] ? " ∈ #{meta[:domain]}" : ""
        "  #{name}#{type}#{dom}"
      end

      def format_decl_header(ctx, decl, idx)
        inferred = ctx.state[:inferred_types]&.[](decl.name)
        type_note = inferred ? " (#{format_type(inferred, decl)})" : ""
        vec_meta  = ctx.state[:vec_meta]&.[](:"#{decl.name}__vec")
        shape =
          if decl.shape == :vec && vec_meta
            inner = vec_meta[:has_idx] ? "nested_arrays" : "flat_array"
            scope = vec_meta[:scope]&.any? ? " by :#{vec_meta[:scope].join(', :')}" : ""
            "[public: #{inner}#{type_note}#{scope}] (twin: vec[#{vec_meta[:has_idx] ? 'indexed' : 'ravel'}][:#{vec_meta[:scope].join(', :')}])"
          else
            "[public: #{decl.shape}#{type_note}]"
          end

        op_counts = if ctx.opts.annotators.include?(:op_counts)
          counts = decl.ops.group_by(&:tag).transform_values(&:size)
          " (#{decl.ops.size} ops: #{counts.map { |k,v| "#{k}=#{v}" }.join(', ')})"
        else
          ""
        end

        "[#{idx}] #{decl.kind.to_s.upcase} #{decl.name} #{shape}#{op_counts}"
      end

      def format_op(ctx, decl, op, i)
        case op.tag
        when :const
          v = op.attrs[:value]
          t = case v; when String then " (str)"; when Integer then " (int)"; when Float then " (float)"; when TrueClass, FalseClass then " (bool)"; else "" end
          "#{i}: CONST #{v.inspect}#{t} → s#{i}"

        when :load_input
          plan_id = op.attrs[:plan_id]
          scope   = op.attrs[:scope] || []
          is_s    = op.attrs[:is_scalar]
          has_idx = op.attrs[:has_idx]
          path, mode = plan_id.to_s.split(":", 2)
          shape = if is_s
            "scalar"
          else
            (has_idx ? "vec[indexed]" : "vec[ravel]") + (scope.any? ? "[:#{scope.join(', :')}]" : "")
          end
          "#{i}: #{path} → #{shape} → s#{i}"

        when :ref
          name = op.attrs[:name]
          if name.to_s.end_with?("__vec")
            meta = ctx.state[:vec_meta]&.[](name)
            scope = meta&.[](:scope) || []
            tag = meta && meta[:has_idx] ? "vec[indexed]" : "vec[ravel]"
            "#{i}: REF #{name} → #{tag}#{scope.any? ? "[:#{scope.join(', :')}]" : ""} → s#{i}"
          else
            "#{i}: REF #{name} → scalar → s#{i}"
          end

        when :map
          fn = op.attrs[:fn]; argc = op.attrs[:argc]
          args = op.args.map { |s| "s#{s}" }.join(", ")
          "#{i}: MAP #{fn}(#{args}) → s#{i}"

        when :reduce
          fn = op.attrs[:fn]; axis = op.attrs[:axis] || []; rs = op.attrs[:result_scope] || []
          args = op.args.map { |s| "s#{s}" }.join(", ")
          result = rs.empty? ? "scalar" : "grouped_vec[:#{rs.join(', :')}]"
          axis_s = axis.empty? ? "" : " axis=[:#{axis.join(', :')}]"
          "#{i}: REDUCE #{fn}(#{args})#{axis_s} → #{result} → s#{i}"

        when :array
          args = op.args.map { |s| "s#{s}" }.join(", ")
          size = op.attrs[:size] || op.args.size
          "#{i}: ARRAY [#{args}] (#{size} elements) → s#{i}"

        when :switch
          cases = op.attrs[:cases] || []
          d = op.attrs[:default]
          pairs = cases.map { |(c,v)| "s#{c}→s#{v}" }.join(", ")
          "#{i}: SWITCH {#{pairs}#{d ? " else s#{d}" : ""}} → s#{i}"

        when :lift
          sc = op.attrs[:to_scope] || []
          "#{i}: LIFT s#{op.args.first} #{sc.any? ? "@:#{sc.join(', :')}" : ""} → nested_arrays → s#{i}"

        when :align_to
          sc = op.attrs[:to_scope] || []
          tgt, src = op.args
          flags = []
          flags << "unique" if op.attrs[:require_unique]
          flags << "on_missing=#{op.attrs[:on_missing]}" if op.attrs[:on_missing] && op.attrs[:on_missing] != :error
          "#{i}: ALIGN_TO target=s#{tgt} source=s#{src} to #{sc.any? ? "[:#{sc.join(', :')}]" : "[]"}#{flags.empty? ? "" : " (#{flags.join(', ')})"} → s#{i}"

        when :store
          name = op.attrs[:name]; src = op.args.first
          "#{i}: STORE #{name}#{name.to_s.end_with?("__vec") ? " (vec twin)" : " (public)"} ← s#{src}"

        when :guard_push
          "#{i}: GUARD_PUSH s#{op.attrs[:cond_slot]}"

        when :guard_pop
          "#{i}: GUARD_POP"

        else
          attrs = op.attrs.map { |k,v| "#{k}=#{v.inspect}" }.join(", ")
          args = op.args.map { |s| "s#{s}" }.join(", ")
          "#{i}: #{op.tag.to_s.upcase} #{attrs.empty? ? "" : "{#{attrs}}"} #{args.empty? ? "" : "args=[#{args}]"} → s#{i}"
        end
      end

      # ---- small helpers ----

      def format_type(inferred, decl)
        case inferred
        when Symbol then inferred.to_s.capitalize
        when Hash
          if inferred.key?(:array)
            inner = inferred[:array]
            inner.is_a?(Symbol) ? inner.to_s.capitalize : inner.to_s
          else
            inferred.inspect
          end
        else
          decl.is_a?(Kumi::Syntax::TraitDeclaration) ? "Boolean" : inferred.class.name.split("::").last
        end
      end

      def format_plans(ctx)
        out = []
        if (order = ctx.state[:evaluation_order])
          out << "EVAL ORDER: #{order.join(' → ')}"
          out << ""
        end
        if (plans = ctx.state[:access_plans])
          total = plans.values.map(&:size).sum
          out << "ACCESS PLANS (#{plans.size} paths, #{total} plans):"
          plans.each do |path, list|
            out << "  #{path}:"
            list.each do |p|
              mode = p.mode
              scope = p.scope.any? ? " @#{p.scope.join('.')}" : ""
              out << "    #{p.accessor_key} → #{mode}#{scope} (depth=#{p.depth})"
            end
          end
          out << ""
        end
        if (vec = ctx.state[:vec_meta]).is_a?(Hash)
          out << "VECTOR TWINS:"
          if vec.empty?
            out << "  (none)"
          else
            vec.each do |name, meta|
              scope = meta[:scope] || []
              out << "  #{name}: #{meta[:has_idx] ? 'indexed' : 'ravel'} [:#{scope.join(', :')}]"
            end
          end
          out << ""
        end
        out.join("\n")
      end

      def compact_state(ctx)
        keys = %i[evaluation_order access_plans join_reduce_plans scope_plans vec_meta inferred_types]
        ctx.state.slice(*keys)
      end

      # ------------- failure helpers -------------

      def with_dump_on_exception(path: ENV["DUMP_IR_ON_FAIL"], analysis_state: nil, format: :text, opts: {})
        return yield unless path # nothing configured
        begin
          yield
        rescue => e
          File.open(path, "w") { |io| io.puts("EXCEPTION: #{e.class}: #{e.message}\n\n"); io.puts("-- IR DUMP --\n"); dump(yield_current_ir_module, analysis_state: analysis_state, to: io, format: format, opts: opts) } rescue nil
          raise
        end
      end

      # caller should hand us the module when they know it; for generic rescue paths
      def dump_if(condition, ir_module, analysis_state:, path:, format: :text, opts: {})
        return unless condition && path
        File.open(path, "w") { |io| dump(ir_module, analysis_state: analysis_state, to: io, format: format, opts: opts) }
      end

      # (Optional) override in your environment to expose last module
      def yield_current_ir_module
        # no-op; wire this from the pass if you want to use with_dump_on_exception without arguments
        raise "IRDump.yield_current_ir_module not wired"
      end
    end
  end
end