module SchemaModule
  # Generated code with pack hash: 7b0c3825a5325b3606a4a4a0cfd529e4c603cda03c1c5bbc473d8eef8c055597:ec0d980a55483df151a319632a2667a11be2c976c03ec78a79f178a9fc529957:9229a92c0194d2e87b299873465851c4f35e447fcae59c33cbe09653deec14ee

  def _each_cube
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      op0 = a0
      yield op0, [i0]
    end
  end

  def _eval_cube
    __materialize_from_each(:cube)
  end

  def _each_layer
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        op1 = a1
        yield op1, [i0, i1]
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
          op2 = a2
          yield op2, [i0, i1, i2]
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
          op3 = a2
          yield op3, [i0, i1, i2]
        end
      end
    end
  end

  def _eval_cell
    __materialize_from_each(:cell)
  end

  def _each_cell_over_limit
    op5 = 100
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          op4 = a2
          op6 = __call_kernel__("core.gt", op4, 100)
          yield op6, [i0, i1, i2]
        end
      end
    end
  end

  def _eval_cell_over_limit
    __materialize_from_each(:cell_over_limit)
  end

  def _each_cell_sum
    op9 = 0
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        acc_11 = 0
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          op7 = self[:cell_over_limit][i0][i1][i2]
          op8 = a2
          op10 = (op7 ? op8 : 0)
          acc_11 = __call_kernel__("agg.sum", acc_11, op10)
        end
        op11 = acc_11
        yield op11, [i0, i1]
      end
    end
  end

  def _eval_cell_sum
    __materialize_from_each(:cell_sum)
  end

  def _each_count_over_limit
    acc_18 = 0
    op13 = 1
    op14 = 0
    arr0 = @input["cube"]
    arr0.each_with_index do |a0, i0|
      acc_17 = 0
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        acc_16 = 0
        arr2 = a1
        arr2.each_with_index do |a2, i2|
          op12 = self[:cell_over_limit][i0][i1][i2]
          op15 = (op12 ? 1 : 0)
          acc_16 = __call_kernel__("agg.sum", acc_16, op15)
        end
        op16 = acc_16
        acc_17 = __call_kernel__("agg.sum", acc_17, op16)
      end
      op17 = acc_17
      acc_18 = __call_kernel__("agg.sum", acc_18, op17)
    end
    op18 = acc_18
    yield op18, []
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