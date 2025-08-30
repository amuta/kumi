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

        when :items_subtotal then items_subtotal
        when :items_discounted then items_discounted
        when :items_is_big then items_is_big
        when :items_effective then items_effective
        when :total_qty then total_qty
        when :cart_total then cart_total
        when :cart_total_effective then cart_total_effective
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_core_mul_ruby_v1(a, b)
        a * b
      end
      
      def k_core_sub_ruby_v1(a, b)
        a - b
      end
      
      def k_core_gt_ruby_v1(a, b)
        a > b
      end
      
      def k_agg_sum_ruby_v1(a,b)
        a + b
      end

      def items_subtotal
        # ops: 0:LoadInput, 1:LoadInput, 2:Map
        op_0 = fetch_items_price(@d)
        op_1 = fetch_items_qty(@d)
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

      def items_discounted
        # ops: 0:LoadInput, 1:Const, 2:LoadInput, 3:Map, 4:Map
        op_0 = fetch_items_price(@d)
        op_1 = 1.0
        op_2 = fetch_discount(@d)
        op_3 = k_core_sub_ruby_v1(op_1, op_2)
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_mul_ruby_v1(op_0[i0], op_3)
          i0 += 1
        end
        op_4 = out0
        op_4
      end

      def items_is_big
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_items_price(@d)
        op_1 = 100.0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_gt_ruby_v1(op_0[i0], op_1)
          i0 += 1
        end
        op_2 = out0
        op_2
      end

      def items_effective
        # ops: 0:LoadDeclaration, 1:LoadDeclaration, 2:Const, 3:Map, 5:Select
        op_0 = items_is_big
        op_1 = items_subtotal
        op_2 = 0.9
        n0 = op_1.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = k_core_mul_ruby_v1(op_1[i0], op_2)
          i0 += 1
        end
        op_3 = out0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          out0[i0] = (op_0[i0] ? op_3[i0] : op_1[i0])
          i0 += 1
        end
        op_5 = out0
        op_5
      end

      def total_qty
        # ops: 0:LoadInput, 1:Reduce
        op_0 = fetch_items_qty(@d)
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

      def cart_total
        # ops: 0:LoadDeclaration, 1:Reduce
        op_0 = items_subtotal
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

      def cart_total_effective
        # ops: 0:LoadDeclaration, 1:Reduce
        op_0 = items_effective
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

      def fetch_items(data)
        data = (data[:items] || data["items"]) || (raise "Missing key: items")
        data
      end

      def fetch_items_price(data)
        data = (data[:items] || data["items"]) || (raise "Missing key: items")
        data = data.map { |it0| (it0[:price] || it0["price"]) || (raise "Missing key: price") }
        data
      end

      def fetch_items_qty(data)
        data = (data[:items] || data["items"]) || (raise "Missing key: items")
        data = data.map { |it0| (it0[:qty] || it0["qty"]) || (raise "Missing key: qty") }
        data
      end

      def fetch_discount(data)
        data = (data[:discount] || data["discount"]) || (raise "Missing key: discount")
        data
      end
    end
  end
end
