# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "81aa6e3e4dcad24a5a871d0bbea49e57923e3b571cff0543d3a0d9dee137de1a:3ac9d1b0a8327e848f58e967a80f1098110087cb2da09ae085fb3ee85339433d:ceadd786494ca24eba7e856ae169b3f9a404987ad08ce9ea0e41bc8ed0400239:89e82912e5f75c5377da66c2b13a4796ce5f30e726ae4915f10d80da99f2debd".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :double then (@memo[:double] ||= _eval_double)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

        def _eval_double
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_X_Y_Z, input, cursors)
        v1 = 2
        v2 = __call_kernel__("core.mul", v0, v1)
    
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
    CHAIN_X_Y = [{"key"=>"x", "kind"=>"field_leaf"}, {"key"=>"y", "kind"=>"field_leaf"}].freeze
    CHAIN_X_Y_Z = [{"key"=>"x", "kind"=>"field_leaf"}, {"key"=>"y", "kind"=>"field_leaf"}, {"key"=>"z", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["core.mul"] = ( ->(a, b) { a * b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
