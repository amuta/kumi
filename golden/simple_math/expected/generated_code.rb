# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT
require 'json'

module SchemaModule
  PACK_HASH = "9475af2b2eeded0d4db39c94a9a30184f30e6dcfd214101136fe66c77ccd4fd1:4f0640410c18b2d7e4d34abf0a00d3c54790985559518e0424105d0a5ac96542:4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945:accf27a6abaf85aea1d27e3422c8d85bd8aaa6f8a06b88a14dba66c54659a54f".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :sum then (@memo[:sum] ||= _eval_sum)
                  when :product then (@memo[:product] ||= _eval_product)
                  when :difference then (@memo[:difference] ||= _eval_difference)
                  when :results_array then (@memo[:results_array] ||= _eval_results_array)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

        def _eval_sum
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_X, input, cursors)
        v1 = __walk__(CHAIN_Y, input, cursors)
        v2 = __call_kernel__("core.add", v0, v1)
    
          v2
        end
    
        def _eval_product
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_X, input, cursors)
        v1 = __walk__(CHAIN_Y, input, cursors)
        v2 = __call_kernel__("core.mul", v0, v1)
    
          v2
        end
    
        def _eval_difference
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_X, input, cursors)
        v1 = __walk__(CHAIN_Y, input, cursors)
        v2 = __call_kernel__("core.sub", v0, v1)
    
          v2
        end
    
        def _eval_results_array
          input = @input
          cursors = {}
        v0 = 1
        v1 = __walk__(CHAIN_X, input, cursors)
        v2 = 10
        v3 = __call_kernel__("core.add", v1, v2)
        v4 = __walk__(CHAIN_Y, input, cursors)
        v5 = 2
        v6 = __call_kernel__("core.mul", v4, v5)
        v7 = [v0, v3, v6]
    
          v7
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
    CHAIN_X = JSON.parse("[{\"kind\":\"field_leaf\",\"key\":\"x\"}]").freeze
    CHAIN_Y = JSON.parse("[{\"kind\":\"field_leaf\",\"key\":\"y\"}]").freeze

    KERNELS = {}
    KERNELS["core.add"] = ( ->(a, b) { a + b } )
    KERNELS["core.mul"] = ( ->(a, b) { a * b } )
    KERNELS["core.sub"] = ( ->(a, b) { a - b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
