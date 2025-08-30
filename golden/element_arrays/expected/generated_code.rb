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

        when :cube then cube
        when :layer then layer
        when :row then row
        when :cell then cell
        when :cell_over_limit then cell_over_limit
        when :cell_sum then cell_sum
        when :count_over_limit then count_over_limit
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_core_gt_ruby_v1(a, b)
        a > b
      end
      
      def k_agg_sum_ruby_v1(a,b)
        a + b
      end

      def cube
        # ops: 0:LoadInput
        op_0 = fetch_cube(@d)
        op_0
      end

      def layer
        # ops: 0:LoadInput
        op_0 = fetch_cube_layer(@d)
        op_0
      end

      def row
        # ops: 0:LoadInput
        op_0 = fetch_cube_layer_row(@d)
        op_0
      end

      def cell
        # ops: 0:LoadInput
        op_0 = fetch_cube_layer_row_cell(@d)
        op_0
      end

      def cell_over_limit
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_cube_layer_row_cell(@d)
        op_1 = 100
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
              out2[i2] = k_core_gt_ruby_v1(op_0[i0][i1][i2], op_1)
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_2 = out0
        op_2
      end

      def cell_sum
        # ops: 0:LoadDeclaration, 1:LoadInput, 2:Const, 3:Select, 4:Reduce
        op_0 = cell_over_limit
        op_1 = fetch_cube_layer_row_cell(@d)
        op_2 = 0
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
              out2[i2] = (op_0[i0][i1][i2] ? op_1[i0][i1][i2] : op_2)
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_3 = out0
        n0 = op_3.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_3[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
            row = op_3[i0][i1]
            raise "Empty row at reduce op 4" if row.empty?
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
        op_4 = out0
        op_4
      end

      def count_over_limit
        # ops: 0:LoadDeclaration, 1:Const, 2:Const, 3:Select, 4:Reduce, 5:Reduce, 6:Reduce
        op_0 = cell_over_limit
        op_1 = 1
        op_2 = 0
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
              out2[i2] = (op_0[i0][i1][i2] ? op_1 : op_2)
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_3 = out0
        n0 = op_3.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_3[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
            row = op_3[i0][i1]
            raise "Empty row at reduce op 4" if row.empty?
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
        op_4 = out0
        n0 = op_4.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          row = op_4[i0]
          raise "Empty row at reduce op 5" if row.empty?
          acc = row[0]
          j = 1
          while j < row.length
            acc = k_agg_sum_ruby_v1(acc, row[j])
            j += 1
          end
        out0[i0] = acc
        i0 += 1
        end
        op_5 = out0
        row = op_5
        raise "Empty row at reduce op 6" if row.empty?
        acc = row[0]
        j = 1
        while j < row.length
          acc = k_agg_sum_ruby_v1(acc, row[j])
          j += 1
        end
        op_6 = acc
        op_6
      end

      def fetch_cube(data)
        data = (data[:cube] || data["cube"]) || (raise "Missing key: cube")
        data
      end

      def fetch_cube_layer(data)
        data = (data[:cube] || data["cube"]) || (raise "Missing key: cube")
        data
      end

      def fetch_cube_layer_row(data)
        data = (data[:cube] || data["cube"]) || (raise "Missing key: cube")
        data
      end

      def fetch_cube_layer_row_cell(data)
        data = (data[:cube] || data["cube"]) || (raise "Missing key: cube")
        data
      end
    end
  end
end
