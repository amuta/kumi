module SchemaModule
  # Generated code with pack hash: 7b0c3825a5325b3606a4a4a0cfd529e4c603cda03c1c5bbc473d8eef8c055597:dfb6d5aa0c60e3ffc12f8a29c793c0ffd3433aba89e4ada5416d8fe132e3b3ac:855bb2591854da72a60a0c682d65bf5d9ee6ac9b4ebbf8957a511d897e0ce74f

  def _each_cell
    # TODO: Implement streaming method for cell
    arr0 = @input["cube"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["layer"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["row"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
          v0 = a2
          yield v0, [i0, i1, i2]
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_cell
    # TODO: Implement materialization for cell
    __materialize_from_each(:cell)
  end

  def _each_cell_over_limit
    # TODO: Implement streaming method for cell_over_limit
    arr0 = @input["cube"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["layer"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["row"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
    c1 = 100
    c1 = 100
          v0 = a2
          v2 = __call_kernel__("core.gt", v0, c1)
          yield v2, [i0, i1, i2]
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_cell_over_limit
    # TODO: Implement materialization for cell_over_limit
    __materialize_from_each(:cell_over_limit)
  end

  def _each_cell_sum
    # TODO: Implement streaming method for cell_sum
        acc_4 = 0
    arr0 = @input["cube"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["layer"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
    c2 = 0
    c2 = 0
        yield v4, [i0, i1, i2]
          v0 = self[:cell_over_limit][i0][i1][i2]
          v1 = a2
          v3 = (v0 ? v1 : c2)
          acc_4 += v3
        i1 += 1
      end
      i0 += 1
    end
        v4 = acc_4
  end

  def _eval_cell_sum
    # TODO: Implement materialization for cell_sum
    __materialize_from_each(:cell_sum)
  end

  def _each_count_over_limit
    # TODO: Implement streaming method for count_over_limit
    acc_6 = 0
      acc_5 = 0
        acc_4 = 0
    c1 = 1
    c2 = 0
    c1 = 1
    c2 = 0
      acc_6 += v5
        acc_5 += v4
          v0 = self[:cell_over_limit][i0][i1][i2]
          v3 = (v0 ? c1 : c2)
          acc_4 += v3
    v6 = acc_6
      v5 = acc_5
        v4 = acc_4
    yield v6, [i0, i1, i2]
  end

  def _eval_count_over_limit
    # TODO: Implement materialization for count_over_limit
    __materialize_from_each(:count_over_limit)
  end

  def _each_cube
    # TODO: Implement streaming method for cube
    arr0 = @input["cube"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      v0 = a0
      yield v0, [i0]
      i0 += 1
    end
  end

  def _eval_cube
    # TODO: Implement materialization for cube
    __materialize_from_each(:cube)
  end

  def _each_layer
    # TODO: Implement streaming method for layer
    arr0 = @input["cube"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["layer"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        v0 = a1
        yield v0, [i0, i1]
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_layer
    # TODO: Implement materialization for layer
    __materialize_from_each(:layer)
  end

  def _each_row
    # TODO: Implement streaming method for row
    arr0 = @input["cube"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["layer"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["row"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
          v0 = a2
          yield v0, [i0, i1, i2]
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_row
    # TODO: Implement materialization for row
    __materialize_from_each(:row)
  end

  def [](name)
    case name
    when :cell then _eval_cell
    when :cell_over_limit then _eval_cell_over_limit
    when :cell_sum then _eval_cell_sum
    when :count_over_limit then _eval_count_over_limit
    when :cube then _eval_cube
    when :layer then _eval_layer
    when :row then _eval_row
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
    # TODO: Implement streaming to nested array conversion
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