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

        when :per_order_qty_sum then per_order_qty_sum
        when :order_item_flags then order_item_flags
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_agg_sum_ruby_v1(a,b)
        a + b
      end
      
      def k_core_gt_ruby_v1(a, b)
        a > b
      end

      def per_order_qty_sum
        # ops: 0:LoadInput, 1:Reduce
        op_0 = fetch_orders_items_qty(@d)
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

      def order_item_flags
        # ops: 0:LoadInput, 1:Const, 2:Map
        op_0 = fetch_orders_items_qty(@d)
        op_1 = 0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
            out1[i1] = k_core_gt_ruby_v1(op_0[i0][i1], op_1)
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_2 = out0
        op_2
      end

      def fetch_orders(data)
        data = (data[:orders] || data["orders"]) || (raise "Missing key: orders")
        data
      end

      def fetch_orders_items(data)
        data = (data[:orders] || data["orders"]) || (raise "Missing key: orders")
        data = data.map { |it0| (it0[:items] || it0["items"]) || (raise "Missing key: items") }
        data
      end

      def fetch_orders_items_qty(data)
        data = (data[:orders] || data["orders"]) || (raise "Missing key: orders")
        data = data.map { |it0| (it0[:items] || it0["items"]) || (raise "Missing key: items") }
        data = data.map { |it0| it0.map { |it1| (it1[:qty] || it1["qty"]) || (raise "Missing key: qty") } }
        data
      end

      def fetch_inventory(data)
        data = (data[:inventory] || data["inventory"]) || (raise "Missing key: inventory")
        data
      end

      def fetch_inventory_items(data)
        data = (data[:inventory] || data["inventory"]) || (raise "Missing key: inventory")
        data = data.map { |it0| (it0[:items] || it0["items"]) || (raise "Missing key: items") }
        data
      end

      def fetch_inventory_items_sku(data)
        data = (data[:inventory] || data["inventory"]) || (raise "Missing key: inventory")
        data = data.map { |it0| (it0[:items] || it0["items"]) || (raise "Missing key: items") }
        data = data.map { |it0| it0.map { |it1| (it1[:sku] || it1["sku"]) || (raise "Missing key: sku") } }
        data
      end
    end
  end
end
