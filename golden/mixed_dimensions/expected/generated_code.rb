# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "f44d91e185ff1c868d513173f5a3ee4e627ca4926567004a61d91a74a335e999:0454d172bfd4a01c4a45b10799d50e6b30118978e51576564be2260031b2b43c:d1b3f2fd806df597deeb0cc7cec61c54ccc32b929f224da88672013c073c2a39".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :constant then (@memo[:constant] ||= _eval_constant)
                  when :matrix_sums then (@memo[:matrix_sums] ||= _eval_matrix_sums)
                  when :mixed_array then (@memo[:mixed_array] ||= _eval_mixed_array)
                  when :sum_numbers then (@memo[:sum_numbers] ||= _eval_sum_numbers)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

        def _eval_constant
          input = @input
          cursors = {}
        v0 = 42
    
          v0
        end
    
                def _eval_matrix_sums
                  input = @input
            
                  out = []
    __each_array__(input, "matrix") do |a_matrix|
      acc = 0
        a_matrix.each_with_index do |a_row, _idx|
            cursors = { "matrix"=>a_matrix,"row"=>a_row }
            inl_inline_v0 = __walk__(CHAIN_MATRIX_ROW_CELL, input, cursors)
            acc += inl_inline_v0
        end
      out << acc
    end
    
                  out
                end
    
        def _eval_mixed_array
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_SCALAR_VAL, input, cursors)
        v1 = _eval_sum_numbers
        v3 = [v0, v1, v2]
        v2 = __walk__(CHAIN_MATRIX_ROW_CELL, input, cursors)
          v3
        end
    
        def _eval_sum_numbers
          input = @input
    
          acc = 0
          __each_array__(input, "numbers") do |a_numbers|
      cursors = { "numbers"=>a_numbers }
      inl_inline_v0 = __walk__(CHAIN_NUMBERS_VALUE, input, cursors)
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
    CHAIN_NUMBERS = [{"axis"=>"numbers", "key"=>"numbers", "kind"=>"array_field"}].freeze
    CHAIN_NUMBERS_VALUE = [{"axis"=>"numbers", "key"=>"numbers", "kind"=>"array_field"}, {"key"=>"value", "kind"=>"field_leaf"}].freeze
    CHAIN_SCALAR_VAL = [{"key"=>"scalar_val", "kind"=>"field_leaf"}].freeze
    CHAIN_MATRIX = [{"axis"=>"matrix", "key"=>"matrix", "kind"=>"array_field"}].freeze
    CHAIN_MATRIX_ROW = [{"axis"=>"matrix", "key"=>"matrix", "kind"=>"array_field"}, {"axis"=>"row", "key"=>"row", "kind"=>"array_field"}].freeze
    CHAIN_MATRIX_ROW_CELL = [{"axis"=>"matrix", "key"=>"matrix", "kind"=>"array_field"}, {"axis"=>"row", "key"=>"row", "kind"=>"array_field"}, {"key"=>"cell", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["agg.sum"] = ( ->(a,b) { a + b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
