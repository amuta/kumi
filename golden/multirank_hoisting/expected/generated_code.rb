# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "7b6dc6d89c79f8898e4c6b21156755693f7002af79004c14cd3c1c1c18300705:ebd4dbd72b5277205c998985b6f6eeb0f2ebb08fa6c2ac2ccee86376a36e74f9:9d85bf516b106dd0565ab16047155264e04cbd968f14abf38d5740091915f835:9c4cb6c9f7712c85330eaca88c4f5dce7fee1fdf5722c242df9a2bb56021865a".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :batch_bias then (@memo[:batch_bias] ||= _eval_batch_bias)
                  when :batch_total_affine then (@memo[:batch_total_affine] ||= _eval_batch_total_affine)
                  when :elem_affine then (@memo[:elem_affine] ||= _eval_elem_affine)
                  when :global_offset_plus then (@memo[:global_offset_plus] ||= _eval_global_offset_plus)
                  when :row_scale2 then (@memo[:row_scale2] ||= _eval_row_scale2)
                  when :row_sum_affine then (@memo[:row_sum_affine] ||= _eval_row_sum_affine)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

                  def _eval_batch_bias
                    input = @input
                  v1 = _eval_global_offset_plus
                    out = []
    __each_array__(input, "batch") do |a_batch|
        cursors = { "batch"=>a_batch }
          v0 = __walk__(CHAIN_BATCH_MEAN, input, cursors)
          v2 = __call_kernel__("core.add", v0, v1)
        out << v2
      end
                    out
                  end
    
                def _eval_batch_total_affine
                  input = @input
            
                  out = []
    __each_array__(input, "batch") do |a_batch|
      acc = 0
        a_batch.each_with_index do |a_row, _idx|
            cursors = { "batch"=>a_batch,"row"=>a_row }
            inl_elem_affine_v0 = __walk__(CHAIN_BATCH_ROW_COL_VAL, input, cursors)
            inl_row_scale2_v0 = __walk__(CHAIN_BATCH_ROW_SCALE, input, cursors)
            inl_row_scale2_v1 = 2.0
            inl_row_scale2_v2 = __call_kernel__("core.mul", inl_row_scale2_v0, inl_row_scale2_v1)
            inl_elem_affine_v2 = __call_kernel__("core.mul", inl_elem_affine_v0, inl_elem_affine_v1)
            inl_batch_bias_v0 = __walk__(CHAIN_BATCH_MEAN, input, cursors)
            inl_global_offset_plus_v0 = __walk__(CHAIN_GLOBAL_OFFSET, input, cursors)
            inl_global_offset_plus_v1 = 1.0
            inl_global_offset_plus_v2 = __call_kernel__("core.add", inl_global_offset_plus_v0, inl_global_offset_plus_v1)
            inl_batch_bias_v2 = __call_kernel__("core.add", inl_batch_bias_v0, inl_batch_bias_v1)
            inl_elem_affine_v4 = __call_kernel__("core.add", inl_elem_affine_v2, inl_elem_affine_v3)
            acc += inl_inline_v0
        end
      out << acc
    end
    
                  out
                end
    
                  def _eval_elem_affine
                    input = @input
              
                    out = []
    __each_array__(input, "batch") do |a_batch|
      row_0 = []
    a_batch.each_with_index do |a_row, _idx|
        row_1 = []
    a_row.each_with_index do |a_col, _idx|
            cursors = { "batch"=>a_batch,"row"=>a_row,"col"=>a_col }
              v0 = __walk__(CHAIN_BATCH_ROW_COL_VAL, input, cursors)
              v1 = _eval_row_scale2
              v2 = __call_kernel__("core.mul", v0, v1)
              v3 = _eval_batch_bias
              v4 = __call_kernel__("core.add", v2, v3)
            row_1 << v4
          end
          row_0 << row_1
        end
        out << row_0
      end
                    out
                  end
    
        def _eval_global_offset_plus
          input = @input
          cursors = {}
        v0 = __walk__(CHAIN_GLOBAL_OFFSET, input, cursors)
        v1 = 1.0
        v2 = __call_kernel__("core.add", v0, v1)
    
          v2
        end
    
                  def _eval_row_scale2
                    input = @input
                  v1 = 2.0
                    out = []
    __each_array__(input, "batch") do |a_batch|
      row_0 = []
    a_batch.each_with_index do |a_row, _idx|
          cursors = { "batch"=>a_batch,"row"=>a_row }
            v0 = __walk__(CHAIN_BATCH_ROW_SCALE, input, cursors)
            v2 = __call_kernel__("core.mul", v0, v1)
          row_0 << v2
        end
        out << row_0
      end
                    out
                  end
    
                def _eval_row_sum_affine
                  input = @input
            
                  out = []
    __each_array__(input, "batch") do |a_batch|
      row_0 = []
    a_batch.each_with_index do |a_row, _idx|
        acc = 0
          a_row.each_with_index do |a_col, _idx|
                cursors = { "batch"=>a_batch,"row"=>a_row,"col"=>a_col }
                inl_elem_affine_v0 = __walk__(CHAIN_BATCH_ROW_COL_VAL, input, cursors)
                inl_row_scale2_v0 = __walk__(CHAIN_BATCH_ROW_SCALE, input, cursors)
                inl_row_scale2_v1 = 2.0
                inl_row_scale2_v2 = __call_kernel__("core.mul", inl_row_scale2_v0, inl_row_scale2_v1)
                inl_elem_affine_v2 = __call_kernel__("core.mul", inl_elem_affine_v0, inl_elem_affine_v1)
                inl_batch_bias_v0 = __walk__(CHAIN_BATCH_MEAN, input, cursors)
                inl_global_offset_plus_v0 = __walk__(CHAIN_GLOBAL_OFFSET, input, cursors)
                inl_global_offset_plus_v1 = 1.0
                inl_global_offset_plus_v2 = __call_kernel__("core.add", inl_global_offset_plus_v0, inl_global_offset_plus_v1)
                inl_batch_bias_v2 = __call_kernel__("core.add", inl_batch_bias_v0, inl_batch_bias_v1)
                inl_elem_affine_v4 = __call_kernel__("core.add", inl_elem_affine_v2, inl_elem_affine_v3)
                acc += inl_inline_v0
          end
        row_0 << acc
      end
      out << row_0
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
    CHAIN_BATCH = [{"axis"=>"batch", "key"=>"batch", "kind"=>"array_field"}].freeze
    CHAIN_BATCH_MEAN = [{"axis"=>"batch", "key"=>"batch", "kind"=>"array_field"}, {"key"=>"mean", "kind"=>"field_leaf"}].freeze
    CHAIN_BATCH_ROW = [{"axis"=>"batch", "key"=>"batch", "kind"=>"array_field"}, {"axis"=>"row", "key"=>"row", "kind"=>"array_field"}].freeze
    CHAIN_BATCH_ROW_SCALE = [{"axis"=>"batch", "key"=>"batch", "kind"=>"array_field"}, {"axis"=>"row", "key"=>"row", "kind"=>"array_field"}, {"key"=>"scale", "kind"=>"field_leaf"}].freeze
    CHAIN_BATCH_ROW_COL = [{"axis"=>"batch", "key"=>"batch", "kind"=>"array_field"}, {"axis"=>"row", "key"=>"row", "kind"=>"array_field"}, {"axis"=>"col", "key"=>"col", "kind"=>"array_field"}].freeze
    CHAIN_BATCH_ROW_COL_VAL = [{"axis"=>"batch", "key"=>"batch", "kind"=>"array_field"}, {"axis"=>"row", "key"=>"row", "kind"=>"array_field"}, {"axis"=>"col", "key"=>"col", "kind"=>"array_field"}, {"key"=>"val", "kind"=>"field_leaf"}].freeze
    CHAIN_GLOBAL_OFFSET = [{"key"=>"global_offset", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["core.add"] = ( ->(a, b) { a + b } )
    KERNELS["core.mul"] = ( ->(a, b) { a * b } )
    KERNELS["agg.sum"] = ( ->(a,b) { a + b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
