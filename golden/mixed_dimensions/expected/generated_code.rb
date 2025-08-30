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

        when :sum_numbers then sum_numbers
        when :matrix_sums then matrix_sums
        when :mixed_array then mixed_array
        when :constant then constant
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_agg_sum_ruby_v1(a,b)
        a + b
      end

      def sum_numbers
        # ops: 0:LoadInput, 1:Reduce
        op_0 = fetch_numbers_value(@d)
        row = op_0
        raise "Empty row at reduce op 1" if row.empty?
        acc = row[0]
        j = 1
        while j < row.length
          acc = k_agg_sum_ruby_v1(acc, row[j])
          j += 1
        end
        op_1 = acc
        op_1
      end

      def matrix_sums
        # ops: 0:LoadInput, 1:Reduce
        op_0 = fetch_matrix_row_cell(@d)
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

      def mixed_array
        # ops: 0:LoadInput, 1:LoadDeclaration, 2:LoadInput, 3:ConstructTuple
        op_0 = fetch_scalar_val(@d)
        op_1 = sum_numbers
        op_2 = fetch_matrix_row_cell(@d)
        op_3 = [op_0, op_1, op_2]
        op_3
      end

      def constant
        # ops: 0:Const
        op_0 = 42
        op_0
      end

      def fetch_numbers(data)
        data = (data[:numbers] || data["numbers"]) || (raise "Missing key: numbers")
        data
      end

      def fetch_numbers_value(data)
        data = (data[:numbers] || data["numbers"]) || (raise "Missing key: numbers")
        data = data.map { |it0| (it0[:value] || it0["value"]) || (raise "Missing key: value") }
        data
      end

      def fetch_scalar_val(data)
        data = (data[:scalar_val] || data["scalar_val"]) || (raise "Missing key: scalar_val")
        data
      end

      def fetch_matrix(data)
        data = (data[:matrix] || data["matrix"]) || (raise "Missing key: matrix")
        data
      end

      def fetch_matrix_row(data)
        data = (data[:matrix] || data["matrix"]) || (raise "Missing key: matrix")
        data = data.map { |it0| (it0[:row] || it0["row"]) || (raise "Missing key: row") }
        data
      end

      def fetch_matrix_row_cell(data)
        data = (data[:matrix] || data["matrix"]) || (raise "Missing key: matrix")
        data = data.map { |it0| (it0[:row] || it0["row"]) || (raise "Missing key: row") }
        data = data.map { |it0| it0.map { |it1| (it1[:cell] || it1["cell"]) || (raise "Missing key: cell") } }
        data
      end
    end
  end
end
