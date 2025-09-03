# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "6d7abb779097b7907e611765b99c13715812da68fd8973c7f4308d7ed5d7a4dc:63b615a28d2716ce3749bfbda57f3e92c7be5f34224887955cb5f446d8e0fa85:234af5166ea4222d549ed45b78f10f1793c5508e7a0f8e3c2c07a97c62eec919:44467cea4b1a4beaa8a2c8438e3d46f4f216807ba3465ea1a0fdf527183550e0".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :status then (@memo[:status] ||= _eval_status)
                  when :x_positive then (@memo[:x_positive] ||= _eval_x_positive)
                  when :y_positive then (@memo[:y_positive] ||= _eval_y_positive)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

        def _eval_status
          input = @input
          cursors = {}
        v0 = _eval_y_positive
        v1 = _eval_x_positive
        v2 = __call_kernel__("core.and", v0, v1)
        v3 = "both positive"
        v5 = "x positive"
        v7 = "y positive"
        v8 = "neither positive"
        v9 = (v0 ? v7 : v8)
        v10 = (v1 ? v5 : v9)
        v11 = (v2 ? v3 : v10)
    
          v11
        end
    
        def _eval_x_positive
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_X, input, cursors)
        v1 = 0
        v2 = __call_kernel__("core.gt", v0, v1)
    
          v2
        end
    
        def _eval_y_positive
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_Y, input, cursors)
        v1 = 0
        v2 = __call_kernel__("core.gt", v0, v1)
    
          v2
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
    CHAIN_X = [{"key"=>"x", "kind"=>"field_leaf"}].freeze
    CHAIN_Y = [{"key"=>"y", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["core.gt"] = ( ->(a, b) { a > b } )
    KERNELS["core.and"] = ( ->(a, b) { a && b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
