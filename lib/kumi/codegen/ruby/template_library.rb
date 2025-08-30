# frozen_string_literal: true

module Kumi
  module Codegen
    class RubyV2
      class TemplateLibrary
        def initialize(options)
          @options = options
        end

        def emit_operation(op, template)
          case template
          when :const_scalar      then emit_const_scalar(op)
          when :load_input        then emit_load_input(op)
          when :align_to_noop     then "" # semantic only
          when :map_generic       then emit_map_generic(op)
          when :select_generic    then emit_select_generic(op)
          when :reduce_last       then emit_reduce_last(op)
          when :construct_tuple   then emit_construct_tuple(op)
          when :load_declaration  then emit_load_declaration(op)
          else
            raise "Unknown template: #{template}"
          end
        end

        private

        # ---------- helpers for code string building ----------
        def build_idx_expr(var, mask, depth)
          idx = []
          (0..depth).each { |d| idx << "[i#{d}]" unless mask[d] }
          "#{var}#{idx.join}"
        end

        def build_prefix_expr(var, depth) # index every axis up to 'depth'
          return var if depth < 0

          "#{var}#{(0..depth).map { |d| "[i#{d}]" }.join}"
        end

        # ---------- primitives ----------
        def emit_const_scalar(op)
          value = op[:args][0]
          lit   = value.is_a?(String) ? value.inspect : value.to_s
          "op_#{op[:id]} = #{lit}"
        end

        def emit_load_input(op)
          path     = op[:args][0]
          accessor = "fetch_#{path.join('_')}"
          "op_#{op[:id]} = #{accessor}(@d)"
        end

        def emit_construct_tuple(op)
          args = op[:args].map { |id| "op_#{id}" }.join(", ")
          "op_#{op[:id]} = [#{args}]"
        end

        def emit_load_declaration(op)
          decl = op[:args][0]
          # call the declaration method directly (no memo)
          "op_#{op[:id]} = #{decl}"
        end

        # ---------- Map (generic with driver + masks) ----------
        def emit_map_generic(op)
          kernel_id  = op[:binding] && op[:binding]["kernel_id"] or raise "missing kernel_id for Map"
          args       = op[:args]
          r          = op[:result_axes]
          driver_idx = op[:driver_index]
          masks      = op[:masks]

          lines = []
          lines << %(k_#{op[:id]} = @p.bind_kernel("#{kernel_id}"))

          if r.empty?
            call_args = args.map { |aid| "op_#{aid}" }.join(", ")
            lines << %(op_#{op[:id]} = k_#{op[:id]}.call(#{call_args}))
            return lines.join("\n")
          end

          driver = "op_#{args[driver_idx]}"
          last   = r.length - 1

          r.each_index do |d|
            driver_slice = (d.zero? ? driver : build_prefix_expr(driver, d - 1))
            lines << "n#{d} = #{driver_slice}.length"
            lines << "out#{d} = Array.new(n#{d})"
            lines << "i#{d} = 0"
            lines << "while i#{d} < n#{d}"
          end

          leaf_args = args.each_with_index.map do |aid, j|
            build_idx_expr("op_#{aid}", masks[j], last)
          end.join(", ")
          lines << "  leaf = k_#{op[:id]}.call(#{leaf_args})"

          r.length.times.reverse_each do |d|
            lines << if d == last
                       "  out#{d}[i#{d}] = leaf"
                     else
                       "  out#{d}[i#{d}] = out#{d + 1}"
                     end
            lines << "  i#{d} += 1"
            lines << "end"
          end

          lines << "op_#{op[:id]} = out0"
          lines.join("\n")
        end

        # ---------- Select (same loops, different leaf) ----------
        def emit_select_generic(op)
          args = op[:args]
          raise "select expects 3 args" unless args.length == 3

          r          = op[:result_axes]
          driver_idx = op[:driver_index]
          masks      = op[:masks]

          cond_id, t_id, f_id = args
          lines = []

          if r.empty?
            lines << "op_#{op[:id]} = (op_#{cond_id} ? op_#{t_id} : op_#{f_id})"
            return lines.join("\n")
          end

          driver = "op_#{args[driver_idx]}"
          last   = r.length - 1

          r.each_index do |d|
            driver_slice = (d.zero? ? driver : build_prefix_expr(driver, d - 1))
            lines << "n#{d} = #{driver_slice}.length"
            lines << "out#{d} = Array.new(n#{d})"
            lines << "i#{d} = 0"
            lines << "while i#{d} < n#{d}"
          end

          cond_expr = build_idx_expr("op_#{cond_id}", masks[0], last)
          t_expr    = build_idx_expr("op_#{t_id}",    masks[1], last)
          f_expr    = build_idx_expr("op_#{f_id}",    masks[2], last)
          lines << "  leaf = (#{cond_expr} ? #{t_expr} : #{f_expr})"

          r.length.times.reverse_each do |d|
            lines << if d == last
                       "  out#{d}[i#{d}] = leaf"
                     else
                       "  out#{d}[i#{d}] = out#{d + 1}"
                     end
            lines << "  i#{d} += 1"
            lines << "end"
          end

          lines << "op_#{op[:id]} = out0"
          lines.join("\n")
        end

        # ---------- reduce (last axis only) ----------
        def emit_reduce_last(op)
          kernel_id = op[:binding] && op[:binding]["kernel_id"] or raise "missing kernel_id for reduce"
          src_id    = op[:args][0]
          rprime    = op[:result_axes]

          lines = []
          lines << %(k_#{op[:id]} = @p.bind_kernel("#{kernel_id}"))

          if rprime.empty?
            lines << "row = op_#{src_id}"
            lines << %(raise "Empty row at reduce op #{op[:id]}" if row.empty?) # TODO(muta): identity?
            lines << "acc = row[0]"
            lines << "j = 1"
            lines << "while j < row.length"
            lines << "  acc = k_#{op[:id]}.call(acc, row[j])"
            lines << "  j += 1"
            lines << "end"
            lines << "op_#{op[:id]} = acc"
            return lines.join("\n")
          end

          last = rprime.length - 1
          driver = "op_#{src_id}"

          rprime.each_index do |d|
            driver_slice = (d.zero? ? driver : build_prefix_expr(driver, d - 1))
            lines << "n#{d} = #{driver_slice}.length"
            lines << "out#{d} = Array.new(n#{d})"
            lines << "i#{d} = 0"
            lines << "while i#{d} < n#{d}"
          end

          row_expr = build_prefix_expr(driver, last)
          lines << "  row = #{row_expr}"
          lines << %(  raise "Empty row at reduce op #{op[:id]}" if row.empty?) # TODO(muta): identity?
          lines << "  acc = row[0]"
          lines << "  j = 1"
          lines << "  while j < row.length"
          lines << "    acc = k_#{op[:id]}.call(acc, row[j])"
          lines << "    j += 1"
          lines << "  end"
          lines << "  out#{last}[i#{last}] = acc"

          rprime.length.times.reverse_each do |d|
            lines << "  out#{d}[i#{d}] = out#{d + 1}" unless d == last
            lines << "  i#{d} += 1"
            lines << "end"
          end

          lines << "op_#{op[:id]} = out0"
          lines.join("\n")
        end
      end
    end
  end
end
