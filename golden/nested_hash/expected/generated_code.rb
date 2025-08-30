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

        when :double then double
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_core_mul_ruby_v1(a, b)
        a * b
      end

      def double
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_x_y_z(@d)
        op_1 = 2
        op_2 = k_core_mul_ruby_v1(op_0, op_1)
        op_2
      end

      def fetch_x(data)
        data = (data[:x] || data["x"]) || (raise "Missing key: x")
        data
      end

      def fetch_x_y(data)
        data = (data[:x] || data["x"]) || (raise "Missing key: x")
        data = (data[:y] || data["y"]) || (raise "Missing key: y")
        data
      end

      def fetch_x_y_z(data)
        data = (data[:x] || data["x"]) || (raise "Missing key: x")
        data = (data[:y] || data["y"]) || (raise "Missing key: y")
        data = (data[:z] || data["z"]) || (raise "Missing key: z")
        data
      end
    end
  end
end
