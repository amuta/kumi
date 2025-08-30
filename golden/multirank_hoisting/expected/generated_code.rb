module Generated
  class Program
    def initialize(registry:, assertions: true)
      # registry kept for API compatibility; not used by inlined kernels
      @registry   = registry
      @assertions = assertions
    end

def from(data)
  Bound.new(self, data)
end


class Bound
  def initialize(program, data)
    @p = program
    @d = data
  end

  def [](decl)
    case decl

        when :global_offset_plus then global_offset_plus
        when :batch_bias then batch_bias
        when :row_scale2 then row_scale2
        when :elem_affine then elem_affine
        when :row_sum_affine then row_sum_affine
        when :batch_total_affine then batch_total_affine
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_core_add_ruby_v1(a, b)
        a + b
      end
      
      def k_core_mul_ruby_v1(a, b)
        a * b
      end
      
      def k_agg_sum_ruby_v1(a,b)
        a + b
      end

      def global_offset_plus
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_global_offset(@d)
        op_1 = 1.0
        op_2 = k_core_add_ruby_v1(op_0, op_1)
        op_2
      end

      def batch_bias
        # ops: 0:LoadInput, 1:LoadDeclaration, 2:Map
        op_0 = fetch_batch_mean(@d)
        op_1 = global_offset_plus
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_add_ruby_v1(op_0[i0], op_1)
          i0 += 1
        end
        op_2 = out0
        op_2
      end

      def row_scale2
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_batch_row_scale(@d)
        op_1 = 2.0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
            out1[i1] = k_core_mul_ruby_v1(op_0[i0][i1], op_1)
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_2 = out0
        op_2
      end

      def elem_affine
        # ops: 0:LoadInput, 1:LoadDeclaration, 2:Map, 3:LoadDeclaration, 4:Map
        op_0 = fetch_batch_row_col_val(@d)
        op_1 = row_scale2
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_0[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
              out2[i2] = k_core_mul_ruby_v1(op_0[i0][i1][i2], op_1[i0][i1])
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_2 = out0
        op_3 = batch_bias
        n0 = op_2.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_2[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_2[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
              out2[i2] = k_core_add_ruby_v1(op_2[i0][i1][i2], op_3[i0])
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_4 = out0
        op_4
      end

      def row_sum_affine
        # ops: 0:LoadDeclaration, 1:Reduce
        op_0 = elem_affine
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
            row = op_0[i0][i1]
            raise "Empty row at reduce op 1" if row.empty?
            acc = row[0]
            j = 1
            while j < row.length
              acc = k_agg_sum_ruby_v1(acc, row[j])
              j += 1
            end
          out1[i1] = acc
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_1 = out0
        op_1
      end

      def batch_total_affine
        # ops: 0:LoadDeclaration, 1:Reduce
        op_0 = row_sum_affine
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          row = op_0[i0]
          raise "Empty row at reduce op 1" if row.empty?
          acc = row[0]
          j = 1
          while j < row.length
            acc = k_agg_sum_ruby_v1(acc, row[j])
            j += 1
          end
        out0[i0] = acc
        i0 += 1
        end
        op_1 = out0
        op_1
      end

      def fetch_batch(data)
        data = (data[:batch] || data["batch"]) || (raise "Missing key: batch")
        data
      end

      def fetch_batch_mean(data)
        data = (data[:batch] || data["batch"]) || (raise "Missing key: batch")
        data = data.map { |it0| (it0[:mean] || it0["mean"]) || (raise "Missing key: mean") }
        data
      end

      def fetch_batch_row(data)
        data = (data[:batch] || data["batch"]) || (raise "Missing key: batch")
        data = data.map { |it0| (it0[:row] || it0["row"]) || (raise "Missing key: row") }
        data
      end

      def fetch_batch_row_scale(data)
        data = (data[:batch] || data["batch"]) || (raise "Missing key: batch")
        data = data.map { |it0| (it0[:row] || it0["row"]) || (raise "Missing key: row") }
        data = data.map { |it0| it0.map { |it1| (it1[:scale] || it1["scale"]) || (raise "Missing key: scale") } }
        data
      end

      def fetch_batch_row_col(data)
        data = (data[:batch] || data["batch"]) || (raise "Missing key: batch")
        data = data.map { |it0| (it0[:row] || it0["row"]) || (raise "Missing key: row") }
        data = data.map { |it0| it0.map { |it1| (it1[:col] || it1["col"]) || (raise "Missing key: col") } }
        data
      end

      def fetch_batch_row_col_val(data)
        data = (data[:batch] || data["batch"]) || (raise "Missing key: batch")
        data = data.map { |it0| (it0[:row] || it0["row"]) || (raise "Missing key: row") }
        data = data.map { |it0| it0.map { |it1| (it1[:col] || it1["col"]) || (raise "Missing key: col") } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| (it2[:val] || it2["val"]) || (raise "Missing key: val") } } }
        data
      end

      def fetch_global_offset(data)
        data = (data[:global_offset] || data["global_offset"]) || (raise "Missing key: global_offset")
        data
      end
    end
  end
end
