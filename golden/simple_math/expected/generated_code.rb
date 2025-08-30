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

        when :sum then sum
        when :product then product
        when :difference then difference
        when :results_array then results_array
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
      
      def k_core_sub_ruby_v1(a, b)
        a - b
      end

      def sum
        # ops: 0:LoadInput, 1:LoadInput, 2:Map
        op_0 = fetch_x(@d)
        op_1 = fetch_y(@d)
        op_2 = k_core_add_ruby_v1(op_0, op_1)
        op_2
      end

      def product
        # ops: 0:LoadInput, 1:LoadInput, 2:Map
        op_0 = fetch_x(@d)
        op_1 = fetch_y(@d)
        op_2 = k_core_mul_ruby_v1(op_0, op_1)
        op_2
      end

      def difference
        # ops: 0:LoadInput, 1:LoadInput, 2:Map
        op_0 = fetch_x(@d)
        op_1 = fetch_y(@d)
        op_2 = k_core_sub_ruby_v1(op_0, op_1)
        op_2
      end

      def results_array
        # ops: 0:Const, 1:LoadInput, 2:Const, 3:Map, 4:LoadInput, 5:Const, 6:Map, 7:ConstructTuple
        op_0 = 1
        op_1 = fetch_x(@d)
        op_2 = 10
        op_3 = k_core_add_ruby_v1(op_1, op_2)
        op_4 = fetch_y(@d)
        op_5 = 2
        op_6 = k_core_mul_ruby_v1(op_4, op_5)
        op_7 = [op_0, op_3, op_6]
        op_7
      end

      def fetch_x(data)
        data = (data[:x] || data["x"]) || (raise "Missing key: x")
        data
      end

      def fetch_y(data)
        data = (data[:y] || data["y"]) || (raise "Missing key: y")
        data
      end
    end
  end
end
