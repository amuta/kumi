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

        when :subtotals then subtotals
        when :discounted_price then discounted_price
        when :is_valid_quantity then is_valid_quantity
        when :expensive_items then expensive_items
        when :electronics then electronics
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_core_mul_ruby_v1(a, b)
        a * b
      end
      
      def k_core_gt_ruby_v1(a, b)
        a > b
      end
      
      def k_core_eq_ruby_v1(a, b)
        a == b
      end

      def subtotals
        # ops: 0:LoadInput, 1:LoadInput, 2:Map
        op_0 = fetch_items_price(@d)
        op_1 = fetch_items_quantity(@d)
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_mul_ruby_v1(op_0[i0], op_1[i0])
          i0 += 1
        end
        op_2 = out0
        op_2
      end

      def discounted_price
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_items_price(@d)
        op_1 = 0.9
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_mul_ruby_v1(op_0[i0], op_1)
          i0 += 1
        end
        op_3 = out0
        op_3
      end

      def is_valid_quantity
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_items_quantity(@d)
        op_1 = 0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_gt_ruby_v1(op_0[i0], op_1)
          i0 += 1
        end
        op_3 = out0
        op_3
      end

      def expensive_items
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_items_price(@d)
        op_1 = 100.0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_gt_ruby_v1(op_0[i0], op_1)
          i0 += 1
        end
        op_3 = out0
        op_3
      end

      def electronics
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_items_category(@d)
        op_1 = "electronics"
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_eq_ruby_v1(op_0[i0], op_1)
          i0 += 1
        end
        op_3 = out0
        op_3
      end

      def fetch_items(data)
        data = (data[:items] || data["items"]) || (raise "Missing key: items")
        data
      end

      def fetch_items_price(data)
        data = (data[:items] || data["items"]) || (raise "Missing key: items")
        data = data.map { |it0| (it0[:price] || it0["price"]) || (raise "Missing key: price") }
        data
      end

      def fetch_items_quantity(data)
        data = (data[:items] || data["items"]) || (raise "Missing key: items")
        data = data.map { |it0| (it0[:quantity] || it0["quantity"]) || (raise "Missing key: quantity") }
        data
      end

      def fetch_items_category(data)
        data = (data[:items] || data["items"]) || (raise "Missing key: items")
        data = data.map { |it0| (it0[:category] || it0["category"]) || (raise "Missing key: category") }
        data
      end

      def fetch_tax_rate(data)
        data = (data[:tax_rate] || data["tax_rate"]) || (raise "Missing key: tax_rate")
        data
      end
    end
  end
end
