# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "45bd418c3b845c12482d5e915ee3e4c4b5d939e1f730d49eca35b914ea729ef3:1a12a162d7d91854a456451464ca7691bf5f3c922926fadea9a58a959dae1e77:71094081f55c7aa2aae6462fdc0153ab997138d549724a490e9babc81d1764b4:54f52b116ade892602e3e97a9b105f6b16ecaf4598a5939fcfbfa49b22d54aba".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :cart_total then (@memo[:cart_total] ||= _eval_cart_total)
                  when :cart_total_effective then (@memo[:cart_total_effective] ||= _eval_cart_total_effective)
                  when :items_discounted then (@memo[:items_discounted] ||= _eval_items_discounted)
                  when :items_effective then (@memo[:items_effective] ||= _eval_items_effective)
                  when :items_is_big then (@memo[:items_is_big] ||= _eval_items_is_big)
                  when :items_subtotal then (@memo[:items_subtotal] ||= _eval_items_subtotal)
                  when :total_qty then (@memo[:total_qty] ||= _eval_total_qty)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

        def _eval_cart_total
          input = @input
    
          acc = 0
          __each_array__(input, "items") do |a_items|
      cursors = { "items"=>a_items }
      inl_items_subtotal_v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
      inl_items_subtotal_v1 = __walk__(CHAIN_ITEMS_QTY, input, cursors)
      inl_items_subtotal_v2 = __call_kernel__("core.mul", inl_items_subtotal_v0, inl_items_subtotal_v1)
      acc += inl_inline_v0
    end
    
          acc
        end
    
        def _eval_cart_total_effective
          input = @input
    
          acc = 0
          __each_array__(input, "items") do |a_items|
      cursors = { "items"=>a_items }
      inl_items_is_big_v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
      inl_items_is_big_v1 = 100.0
      inl_items_is_big_v2 = __call_kernel__("core.gt", inl_items_is_big_v0, inl_items_is_big_v1)
      inl_items_subtotal_v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
      inl_items_subtotal_v1 = __walk__(CHAIN_ITEMS_QTY, input, cursors)
      inl_items_subtotal_v2 = __call_kernel__("core.mul", inl_items_subtotal_v0, inl_items_subtotal_v1)
      inl_items_effective_v2 = 0.9
      inl_items_effective_v3 = __call_kernel__("core.mul", inl_items_effective_v1, inl_items_effective_v2)
      inl_items_effective_v5 = (inl_items_is_big_v2 ? inl_items_effective_v3 : inl_items_effective_v1)
      acc += inl_inline_v0
    end
    
          acc
        end
    
                  def _eval_items_discounted
                    input = @input
                  v1 = 1.0
        v2 = __walk__(CHAIN_DISCOUNT, input, cursors)
        v3 = __call_kernel__("core.sub", v1, v2)
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
          v4 = __call_kernel__("core.mul", v0, v3)
        out << v4
      end
                    out
                  end
    
                  def _eval_items_effective
                    input = @input
                  v2 = 0.9
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = _eval_items_is_big
          v1 = _eval_items_subtotal
          v3 = __call_kernel__("core.mul", v1, v2)
          v5 = (v0 ? v3 : v1)
        out << v5
      end
                    out
                  end
    
                  def _eval_items_is_big
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
    
                  def _eval_items_subtotal
                    input = @input
              
                    out = []
    __each_array__(input, "items") do |a_items|
        cursors = { "items"=>a_items }
          v0 = __walk__(CHAIN_ITEMS_PRICE, input, cursors)
          v1 = __walk__(CHAIN_ITEMS_QTY, input, cursors)
          v2 = __call_kernel__("core.mul", v0, v1)
        out << v2
      end
                    out
                  end
    
        def _eval_total_qty
          input = @input
    
          acc = 0
          __each_array__(input, "items") do |a_items|
      cursors = { "items"=>a_items }
      inl_inline_v0 = __walk__(CHAIN_ITEMS_QTY, input, cursors)
      acc += inl_inline_v0
    end
    
          acc
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
    CHAIN_ITEMS_QTY = [{"axis"=>"items", "key"=>"items", "kind"=>"array_field"}, {"key"=>"qty", "kind"=>"field_leaf"}].freeze
    CHAIN_DISCOUNT = [{"key"=>"discount", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["core.mul"] = ( ->(a, b) { a * b } )
    KERNELS["core.sub"] = ( ->(a, b) { a - b } )
    KERNELS["core.gt"] = ( ->(a, b) { a > b } )
    KERNELS["agg.sum"] = ( ->(a,b) { a + b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
