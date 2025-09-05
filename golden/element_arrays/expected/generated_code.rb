module SchemaModule
  # Generated code with pack hash: 7b0c3825a5325b3606a4a4a0cfd529e4c603cda03c1c5bbc473d8eef8c055597:814a3606eafcc1eb22e2d546e4c408946d684962c609bd8a738d11eeff653527:914b3226894c3a3db36f804b583139ac7fdc6fd9a8284cc9eade5e433d6cfd28

  def _each_cube
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      v0 = a0
      yield v0, []
    end
  end

  def _eval_cube
    _each_cube { |value, _| return value }
  end

  def _each_layer
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        v0 = a1
        yield v0, [i0]
      end
    end
  end

  def _eval_layer
    __materialize_from_each(:layer)
  end

  def _each_row
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          v0 = a2
          yield v0, [i0, i1]
        end
      end
    end
  end

  def _eval_row
    __materialize_from_each(:row)
  end

  def _each_cell
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          v0 = a2
          yield v0, [i0, i1, i2]
        end
      end
    end
  end

  def _eval_cell
    __materialize_from_each(:cell)
  end

  def _each_cell_over_limit
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      c1 = 100
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          v0 = a2
          v2 = __call_kernel__("core.gt", v0, c1)
          yield v2, [i0, i1, i2]
        end
      end
    end
  end

  def _eval_cell_over_limit
    __materialize_from_each(:cell_over_limit)
  end

  def _each_cell_sum
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      c2 = 0
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          acc_4 = 0
          v1 = a2
          ccell_over_limit_1 = 100
          v0_cell_over_limit = a2
          v0 = __call_kernel__("core.gt", v0_cell_over_limit, ccell_over_limit_1)
          v3 = (v0_cell_over_limit ? ccell_over_limit_1 : c2)
          acc_4 += v3
          v4 = acc_4
          yield v4, [i0, i1]
        end
      end
    end
  end

  def _eval_cell_sum
    __materialize_from_each(:cell_sum)
  end

  def _each_count_over_limit
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      acc_6 = 0
      c1 = 1
      c2 = 0
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        acc_5 = 0
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          acc_4 = 0
          ccell_over_limit_1 = 100
          v0_cell_over_limit = a2
          v0 = __call_kernel__("core.gt", v0_cell_over_limit, ccell_over_limit_1)
          v3 = (v0_cell_over_limit ? c1 : c2)
          acc_4 += v3
          v4 = acc_4
          acc_5 += v4
          v5 = acc_5
        end
        acc_6 += v5
        v6 = acc_6
      end
      yield v6, []
    end
  end

  def _eval_count_over_limit
    _each_count_over_limit { |value, _| return value }
  end

  def [](name)
    case name
    when :cube then _eval_cube
    when :layer then _eval_layer
    when :row then _eval_row
    when :cell then _eval_cell
    when :cell_over_limit then _eval_cell_over_limit
    when :cell_sum then _eval_cell_sum
    when :count_over_limit then _eval_count_over_limit
    else raise KeyError, "Unknown declaration: #{name}"
    end
  end

  def self.from(input_data)
    instance = Object.new
    instance.extend(self)
    instance.instance_variable_set(:@input, input_data)
    instance
  end

  private

  def __materialize_from_each(name)
    result = []
    send("_each_#{name}") do |value, indices|
      __nest_value(result, indices, value)
    end
    result
  end

  def __nest_value(result, indices, value)
    current = result
    indices[0...-1].each do |idx|
      current[idx] ||= []
      current = current[idx]
    end
    current[indices.last] = value if indices.any?
  end

  def __call_kernel__(id, *args)
    # TODO: Implement kernel dispatch
    return (->(a, b) { a > b }).call(*args) if id == "core.gt"
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end