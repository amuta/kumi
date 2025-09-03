# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "33e2e9bd3709df540bc8c2748b78d16c2ca90b2cc92325848a4b868fa39ba7a8:485589dd971491038691260644783edcd604005bb53c5a649d69f328be9c3b31:5ceabfc168da0f10c91bd811df22d4716956b61ca06a1816b9a880c0be5ba011:284d26cdd18929c672d4152c8f16336f789a58d61ee675acac3e59adec62c16e".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :discounted_price then (@memo[:discounted_price] ||= _eval_discounted_price)
                  when :electronics then (@memo[:electronics] ||= _eval_electronics)
                  when :expensive_items then (@memo[:expensive_items] ||= _eval_expensive_items)
                  when :is_valid_quantity then (@memo[:is_valid_quantity] ||= _eval_is_valid_quantity)
                  when :subtotals then (@memo[:subtotals] ||= _eval_subtotals)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

                  def _eval_discounted_price
                    input = @input
                  v1 = 0.9
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
          v2 = __call_kernel__("core.mul", v0, v1)
        out << v2
      end
                    out
                  end
    
                  def _eval_electronics
                    input = @input
                  v1 = "electronics"
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = __walk__(CHAIN_ITEMS_CATEGORY, input, cursors)
          v2 = __call_kernel__("core.eq", v0, v1)
        out << v2
      end
                    out
                  end
    
                  def _eval_expensive_items
                    input = @input
                  v1 = 100.0
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
          v2 = __call_kernel__("core.gt", v0, v1)
        out << v2
      end
                    out
                  end
    
                  def _eval_is_valid_quantity
                    input = @input
                  v1 = 0
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = __walk__(CHAIN_ITEMS_QUANTITY, input, cursors)
          v2 = __call_kernel__("core.gt", v0, v1)
        out << v2
      end
                    out
                  end
    
                  def _eval_subtotals
                    input = @input
              
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
          v1 = __walk__(CHAIN_ITEMS_QUANTITY, input, cursors)
          v2 = __call_kernel__("core.mul", v0, v1)
        out << v2
      end
                    out
                  end

    # === PRIVATE RUNTIME HELPERS (cursor-based, strict) ===
    MISSING_POLICY = {}.freeze
    
    private
    
    def __fetch_key__(obj, key)
      return nil if obj.nil?
      if obj.is_a?(Hash)
        obj.key?(key) ? obj[key] : obj[key.to_sym]
      else
        obj.respond_to?(key) ? obj.public_send(key) : nil
      end
    end
    
    def __array_of__(obj, key)
      arr = __fetch_key__(obj, key)
      return arr if arr.is_a?(Array)
      policy = MISSING_POLICY.fetch(key) { raise "No missing data policy defined for key '#{key}' in pack capabilities" }
      case policy
      when :empty then []
      when :skip  then nil
      else
        raise KeyError, "expected Array at #{key.inspect}, got #{arr.class}"
      end
    end
    
    def __each_array__(obj, key)
      arr = __array_of__(obj, key)
      return if arr.nil?
      i = 0
      while i < arr.length
        yield arr[i]
        i += 1
      end
    end
    
    def __walk__(steps, root, cursors)
      cur = root
      steps.each do |s|
        case s["kind"]
        when "array_field"
          if (ax = s["axis"]) && cursors.key?(ax)
            cur = cursors[ax]
          else
            cur = __fetch_key__(cur, s["key"])
            raise KeyError, "missing key #{s["key"].inspect}" if cur.nil?
          end
        when "field_leaf"
          cur = __fetch_key__(cur, s["key"])
          raise KeyError, "missing key #{s["key"].inspect}" if cur.nil?
        when "array_element"
          ax = s["axis"]; raise KeyError, "missing cursor for #{ax}" unless cursors.key?(ax)
          cur = cursors[ax]
        when "element_leaf"
          # no-op
        else
          raise KeyError, "unknown step kind: #{s["kind"]}"
        end
      end
      cur
    end
    CHAIN_ITEMS = [{"axis"=>"items", "key"=>"items", "kind"=>"array_field"}].freeze
    CHAIN_ITEMS_PRICE = [{"axis"=>"items", "key"=>"items", "kind"=>"array_field"}, {"key"=>"price", "kind"=>"field_leaf"}].freeze
    CHAIN_ITEMS_QUANTITY = [{"axis"=>"items", "key"=>"items", "kind"=>"array_field"}, {"key"=>"quantity", "kind"=>"field_leaf"}].freeze
    CHAIN_ITEMS_CATEGORY = [{"axis"=>"items", "key"=>"items", "kind"=>"array_field"}, {"key"=>"category", "kind"=>"field_leaf"}].freeze
    CHAIN_TAX_RATE = [{"key"=>"tax_rate", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["core.mul"] = ( ->(a, b) { a * b } )
    KERNELS["core.gt"] = ( ->(a, b) { a > b } )
    KERNELS["core.eq"] = ( ->(a, b) { a == b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
