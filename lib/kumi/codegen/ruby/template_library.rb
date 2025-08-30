# frozen_string_literal: true

module Kumi
  module Codegen
    class Ruby
      class TemplateLibrary
        def initialize(options)
          @options = options
        end

        # Entrypoint: return Ruby source for a single scheduled op
        def emit_operation(op, template, ops_by_id = {})
          case template
          when :const_scalar      then emit_const_scalar(op)
          when :load_input        then emit_load_input(op)
          when :align_to_noop     then "" # semantic-only marker
          when :map_scalar        then emit_map_scalar(op, ops_by_id)
          when :map_nary          then emit_map_nary(op, ops_by_id)
          when :select_scalar     then emit_select_scalar(op, ops_by_id)
          when :select_vector     then emit_select_vector(op, ops_by_id)
          when :reduce_last       then emit_reduce_last(op)
          when :construct_tuple   then emit_construct_tuple(op, ops_by_id)
          when :load_declaration  then emit_load_declaration(op)
          else
            raise "Unknown template: #{template}"
          end
        end

        private

        # ---- utilities ----

        # Must mirror emitter’s method-name scheme
        def kernel_method_name(kid)
          "k_" + kid.gsub(/[^a-zA-Z0-9]+/, "_")
        end

        # Build “[i0][i1]..” skipping axes with broadcast=true
        def index_suffix_for(mask_row, rank)
          s = +""
          0.upto(rank - 1) { |k| s << "[i#{k}]" unless mask_row[k] }
          s
        end

        # ---- Map ----

        # Scalar result: single kernel call
        def emit_map_scalar(op, ops_by_id)
          kid  = op[:binding] && op[:binding]["kernel_id"] or raise "missing kernel_id"
          meth = kernel_method_name(kid)
          args = op[:args].map { |id| "op_#{id}" }.join(", ")
          <<~RUBY.strip
            op_#{op[:id]} = #{meth}(#{args})
          RUBY
        end

        # Vector result (rank >= 1): loops over driver’s shape, apply broadcast masks
        def emit_map_nary(op, ops_by_id)
          kid         = op[:binding] && op[:binding]["kernel_id"] or raise "missing kernel_id"
          meth        = kernel_method_name(kid)
          driver_idx  = op[:driver_index] or raise "missing driver_index"
          driver_id   = op[:args][driver_idx] or raise "map needs args"
          result_axes = op[:result_axes] || []
          masks       = op[:masks]       || []
          args = op[:args]

          rank = result_axes.length
          drv  = "op_#{driver_id}"
          lines = []

          if rank == 1
            lines << "n0 = #{drv}.length"
            lines << "out0 = Array.new(n0)"
            lines << "i0 = 0"
            lines << "while i0 < n0"
            call = args.each_with_index.map { |arg_id, j| masks[j][0] ? "op_#{arg_id}" : "op_#{arg_id}[i0]" }.join(", ")
            lines << "  out0[i0] = #{meth}(#{call})"
            lines << "  i0 += 1"
            lines << "end"
            lines << "op_#{op[:id]} = out0"
            return lines.join("\n")
          end

          # rank >= 2
          0.upto(rank - 1) do |k|
            path = (0...k).map { |t| "[i#{t}]" }.join
            lines << "n#{k} = #{drv}#{path}.length"
            lines << "out#{k} = Array.new(n#{k})"
            lines << "i#{k} = 0"
            lines << "while i#{k} < n#{k}"
          end
          args_str = args.each_with_index.map { |arg_id, j| "op_#{arg_id}#{index_suffix_for(masks[j], rank)}" }.join(", ")
          lines << (("  " * rank) + "out#{rank - 1}[i#{rank - 1}] = #{meth}(#{args_str})")
          (rank - 1).downto(0) do |k|
            indent = "  " * k
            lines << "#{indent}i#{k} += 1"
            lines << "#{indent}end"
            if k > 0
              parent_indent = "  " * (k - 1)
              lines << "#{parent_indent}out#{k - 1}[i#{k - 1}] = out#{k}"
            end
          end
          lines << "op_#{op[:id]} = out0"
          lines.join("\n")
        end

        # ---- Select ----

        def emit_select_scalar(op, ops_by_id)
          cid, tid, fid = op[:args]
          "op_#{op[:id]} = (op_#{cid} ? op_#{tid} : op_#{fid})"
        end

        def emit_select_vector(op, ops_by_id)
          cid, tid, fid = op[:args]
          driver_idx  = op[:driver_index] or raise "missing driver_index"
          driver_id   = op[:args][driver_idx]
          result_axes = op[:result_axes] || []
          masks       = op[:masks]       || []

          rank = result_axes.length
          drv  = "op_#{driver_id}"
          lines = []

          if rank == 1
            lines << "n0 = #{drv}.length"
            lines << "out0 = Array.new(n0)"
            lines << "i0 = 0"
            lines << "while i0 < n0"
            c = masks[0][0] ? "op_#{cid}" : "op_#{cid}[i0]"
            t = masks[1][0] ? "op_#{tid}" : "op_#{tid}[i0]"
            f = masks[2][0] ? "op_#{fid}" : "op_#{fid}[i0]"
            lines << "  out0[i0] = (#{c} ? #{t} : #{f})"
            lines << "  i0 += 1"
            lines << "end"
            lines << "op_#{op[:id]} = out0"
            return lines.join("\n")
          end

          0.upto(rank - 1) do |k|
            path = (0...k).map { |t| "[i#{t}]" }.join
            lines << "n#{k} = #{drv}#{path}.length"
            lines << "out#{k} = Array.new(n#{k})"
            lines << "i#{k} = 0"
            lines << "while i#{k} < n#{k}"
          end
          c = "op_#{cid}#{index_suffix_for(masks[0], rank)}"
          t = "op_#{tid}#{index_suffix_for(masks[1], rank)}"
          f = "op_#{fid}#{index_suffix_for(masks[2], rank)}"
          lines << (("  " * rank) + "out#{rank - 1}[i#{rank - 1}] = (#{c} ? #{t} : #{f})")
          (rank - 1).downto(0) do |k|
            indent = "  " * k
            lines << "#{indent}i#{k} += 1"
            lines << "#{indent}end"
            if k > 0
              parent_indent = "  " * (k - 1)
              lines << "#{parent_indent}out#{k - 1}[i#{k - 1}] = out#{k}"
            end
          end
          lines << "op_#{op[:id]} = out0"
          lines.join("\n")
        end

        # ---- Reduce(last axis) ----

        def emit_reduce_last(op)
          kid  = op[:binding] && op[:binding]["kernel_id"] or raise "missing kernel_id"
          meth = kernel_method_name(kid)
          src  = op[:args][0] or raise "reduce needs a source"
          res_rank = (op[:result_axes] || []).length
          src_expr = "op_#{src}"

          lines = []

          if res_rank == 0
            lines << "row = #{src_expr}"
            lines << "raise \"Empty row at reduce op #{op[:id]}\" if row.empty?"
            lines << "acc = row[0]"
            lines << "j = 1"
            lines << "while j < row.length"
            lines << "  acc = #{meth}(acc, row[j])"
            lines << "  j += 1"
            lines << "end"
            lines << "op_#{op[:id]} = acc"
            return lines.join("\n")
          end

          0.upto(res_rank - 1) do |k|
            path = (0...k).map { |t| "[i#{t}]" }.join
            lines << "n#{k} = #{src_expr}#{path}.length"
            lines << "out#{k} = Array.new(n#{k})"
            lines << "i#{k} = 0"
            lines << "while i#{k} < n#{k}"
          end
          path_to_row = (0...res_rank).map { |t| "[i#{t}]" }.join
          lines << (("  " * res_rank) + "row = #{src_expr}#{path_to_row}")
          lines << (("  " * res_rank) + "raise \"Empty row at reduce op #{op[:id]}\" if row.empty?")
          lines << (("  " * res_rank) + "acc = row[0]")
          lines << (("  " * res_rank) + "j = 1")
          lines << (("  " * res_rank) + "while j < row.length")
          lines << (("  " * res_rank) + "  acc = #{meth}(acc, row[j])")
          lines << (("  " * res_rank) + "  j += 1")
          lines << (("  " * res_rank) + "end")
          lines << (("  " * (res_rank - 1)) + "out#{res_rank - 1}[i#{res_rank - 1}] = acc")
          (res_rank - 1).downto(0) do |k|
            indent = "  " * k
            lines << "#{indent}i#{k} += 1"
            lines << "#{indent}end"
            if k > 0
              parent_indent = "  " * (k - 1)
              lines << "#{parent_indent}out#{k - 1}[i#{k - 1}] = out#{k}"
            end
          end
          lines << "op_#{op[:id]} = out0"
          lines.join("\n")
        end

        # ---- trivial ----

        def emit_const_scalar(op)
          v = op[:args][0]
          lit = v.is_a?(String) ? v.inspect : v.to_s
          "op_#{op[:id]} = #{lit}"
        end

        def emit_load_input(op)
          path = op[:args][0]
          "op_#{op[:id]} = fetch_#{path.join('_')}(@d)"
        end

        def emit_construct_tuple(op, ops_by_id)
          args = op[:args].map { |id| "op_#{id}" }.join(", ")
          "op_#{op[:id]} = [#{args}]"
        end

        def emit_load_declaration(op)
          "op_#{op[:id]} = #{op[:args][0]}"
        end
      end
    end
  end
end
