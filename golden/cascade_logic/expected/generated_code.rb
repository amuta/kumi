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

        when :y_positive then y_positive
        when :x_positive then x_positive
        when :status then status
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_core_gt_ruby_v1(a, b)
        a > b
      end
      
      def k_core_and_ruby_v1(a, b)
        a && b
      end

      def y_positive
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_y(@d)
        op_1 = 0
        op_2 = k_core_gt_ruby_v1(op_0, op_1)
        op_2
      end

      def x_positive
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_x(@d)
        op_1 = 0
        op_2 = k_core_gt_ruby_v1(op_0, op_1)
        op_2
      end

      def status
        # ops: 0:LoadDeclaration, 1:LoadDeclaration, 2:Map, 3:Const, 5:Const, 7:Const, 8:Const, 9:Select, 10:Select, 11:Select
        op_0 = y_positive
        op_1 = x_positive
        op_2 = k_core_and_ruby_v1(op_0, op_1)
        op_3 = "both positive"
        op_5 = "x positive"
        op_7 = "y positive"
        op_8 = "neither positive"
        op_9 = (op_0 ? op_7 : op_8)
        op_10 = (op_1 ? op_5 : op_9)
        op_11 = (op_2 ? op_3 : op_10)
        op_11
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
