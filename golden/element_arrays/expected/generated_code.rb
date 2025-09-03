# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "86d470e5a2345ca230734c0ab3d4c11c508571367444ad6b06a0612f182cf46c:81088da78349aa6f57eab3ac498e15b26021f9f421e08348b5559df961febdcd:855bb2591854da72a60a0c682d65bf5d9ee6ac9b4ebbf8957a511d897e0ce74f:f428308d484d07f4e3ebb03b75d71494a4c9b991b6d7cf8a168e2f20fe28ffb4".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :cube then (@memo[:cube] ||= _eval_cube)
                  when :layer then (@memo[:layer] ||= _eval_layer)
                  when :row then (@memo[:row] ||= _eval_row)
                  when :cell then (@memo[:cell] ||= _eval_cell)
                  when :cell_over_limit then (@memo[:cell_over_limit] ||= _eval_cell_over_limit)
                  when :cell_sum then (@memo[:cell_sum] ||= _eval_cell_sum)
                  when :count_over_limit then (@memo[:count_over_limit] ||= _eval_count_over_limit)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

                  def _eval_cube
                    input = @input
              
                    out = []
    __each_array__(input, "cube") do |a_cube|
        cursors = { "cube"=>a_cube }
          v0 = __walk__(CHAIN_CUBE, input, cursors)
        out << v0
      end
                    out
                  end
    
                  def _eval_layer
                    input = @input
              
                    out = []
    __each_array__(input, "cube") do |a_cube|
      row_0 = []
    a_cube.each_with_index do |a_layer, _idx|
          cursors = { "cube"=>a_cube,"layer"=>a_layer }
            v0 = __walk__(CHAIN_CUBE_LAYER, input, cursors)
          row_0 << v0
        end
        out << row_0
      end
                    out
                  end
    
                  def _eval_row
                    input = @input
              
                    out = []
    __each_array__(input, "cube") do |a_cube|
      row_0 = []
    a_cube.each_with_index do |a_layer, _idx|
        row_1 = []
    a_layer.each_with_index do |a_row, _idx|
            cursors = { "cube"=>a_cube,"layer"=>a_layer,"row"=>a_row }
              v0 = __walk__(CHAIN_CUBE_LAYER_ROW, input, cursors)
            row_1 << v0
          end
          row_0 << row_1
        end
        out << row_0
      end
                    out
                  end
    
                  def _eval_cell
                    input = @input
              
                    out = []
    __each_array__(input, "cube") do |a_cube|
      row_0 = []
    a_cube.each_with_index do |a_layer, _idx|
        row_1 = []
    a_layer.each_with_index do |a_row, _idx|
            cursors = { "cube"=>a_cube,"layer"=>a_layer,"row"=>a_row }
              v0 = __walk__(CHAIN_CUBE_LAYER_ROW_CELL, input, cursors)
            row_1 << v0
          end
          row_0 << row_1
        end
        out << row_0
      end
                    out
                  end
    
                  def _eval_cell_over_limit
                    input = @input
                  v1 = 100
                    out = []
    __each_array__(input, "cube") do |a_cube|
      row_0 = []
    a_cube.each_with_index do |a_layer, _idx|
        row_1 = []
    a_layer.each_with_index do |a_row, _idx|
            cursors = { "cube"=>a_cube,"layer"=>a_layer,"row"=>a_row }
              v0 = __walk__(CHAIN_CUBE_LAYER_ROW_CELL, input, cursors)
              v2 = __call_kernel__("core.gt", v0, v1)
            row_1 << v2
          end
          row_0 << row_1
        end
        out << row_0
      end
                    out
                  end
    
                def _eval_cell_sum
                  input = @input
                v2 = 0
                  out = []
    __each_array__(input, "cube") do |a_cube|
      row_0 = []
    a_cube.each_with_index do |a_layer, _idx|
        acc = 0
          a_layer.each_with_index do |a_row, _idx|
                cursors = { "cube"=>a_cube,"layer"=>a_layer,"row"=>a_row }
                inl_cell_over_limit_v0 = __walk__(CHAIN_CUBE_LAYER_ROW_CELL, input, cursors)
                inl_cell_over_limit_v1 = 100
                inl_cell_over_limit_v2 = __call_kernel__("core.gt", inl_cell_over_limit_v0, inl_cell_over_limit_v1)
                inl_inline_v1 = __walk__(CHAIN_CUBE_LAYER_ROW_CELL, input, cursors)
                inl_inline_v3 = (inl_cell_over_limit_v2 ? inl_inline_v1 : 0)
                acc += inl_inline_v3
          end
        row_0 << acc
      end
      out << row_0
    end
    
                  out
                end
    
        def _eval_count_over_limit
          input = @input
        v1 = 1
        v2 = 0
          acc = 0
          __each_array__(input, "cube") do |a_cube|
    a_cube.each_with_index do |a_layer, _idx|
    a_layer.each_with_index do |a_row, _idx|
          cursors = { "cube"=>a_cube,"layer"=>a_layer,"row"=>a_row }
          inl_cell_over_limit_v0 = __walk__(CHAIN_CUBE_LAYER_ROW_CELL, input, cursors)
          inl_cell_over_limit_v1 = 100
          inl_cell_over_limit_v2 = __call_kernel__("core.gt", inl_cell_over_limit_v0, inl_cell_over_limit_v1)
          inl_inline_v3 = (inl_cell_over_limit_v2 ? 1 : 0)
          acc += inl_inline_v3
        end
      end
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
    CHAIN_CUBE = [{"axis"=>"cube", "key"=>"cube", "kind"=>"array_field"}].freeze
    CHAIN_CUBE_LAYER = [{"axis"=>"cube", "key"=>"cube", "kind"=>"array_field"}, {"alias"=>"layer", "axis"=>"layer", "kind"=>"array_element"}].freeze
    CHAIN_CUBE_LAYER_ROW = [{"axis"=>"cube", "key"=>"cube", "kind"=>"array_field"}, {"alias"=>"layer", "axis"=>"layer", "kind"=>"array_element"}, {"alias"=>"row", "axis"=>"row", "kind"=>"array_element"}].freeze
    CHAIN_CUBE_LAYER_ROW_CELL = [{"axis"=>"cube", "key"=>"cube", "kind"=>"array_field"}, {"alias"=>"layer", "axis"=>"layer", "kind"=>"array_element"}, {"alias"=>"row", "axis"=>"row", "kind"=>"array_element"}, {"kind"=>"element_leaf"}].freeze

    KERNELS = {}
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
