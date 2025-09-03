module SchemaModule
  # Generated code with pack hash: af979b2df7c43ac3d200cf659d69e1cad807ccea8c10586e3b9678176ede1570:330ff2cb79c5760eceaf9abae480e47d776177a083e9a5f305b50d57fe168ae3:0454d172bfd4a01c4a45b10799d50e6b30118978e51576564be2260031b2b43c

  def _each_constant
    # TODO: Implement streaming method for constant
    c0 = 42
    c0 = 42
    yield v0, []
  end

  def _eval_constant
    # TODO: Implement materialization for constant
    _each_constant { |value, _| return value }
  end

  def _each_matrix_sums
    # TODO: Implement streaming method for matrix_sums
      acc_1 = 0.0
    arr0 = @input["matrix"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      yield v1, [i0]
        v0 = a1["cell"]
        acc_1 += v0
      i0 += 1
    end
      v1 = acc_1
  end

  def _eval_matrix_sums
    # TODO: Implement materialization for matrix_sums
    __materialize_from_each(:matrix_sums)
  end

  def _each_mixed_array
    # TODO: Implement streaming method for mixed_array
    v0 = @input["scalar_val"]
    v1 = self[:sum_numbers]
    v3 = [v0, v1, v2]
        v2 = a1["cell"]
    yield v3, []
  end

  def _eval_mixed_array
    # TODO: Implement materialization for mixed_array
    _each_mixed_array { |value, _| return value }
  end

  def _each_sum_numbers
    # TODO: Implement streaming method for sum_numbers
    acc_1 = 0.0
    arr0 = @input["numbers"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      v0 = a0["value"]
      acc_1 += v0
      i0 += 1
    end
    v1 = acc_1
    yield v1, []
  end

  def _eval_sum_numbers
    # TODO: Implement materialization for sum_numbers
    _each_sum_numbers { |value, _| return value }
  end

  def [](name)
    case name
    when :constant then _eval_constant
    when :matrix_sums then _eval_matrix_sums
    when :mixed_array then _eval_mixed_array
    when :sum_numbers then _eval_sum_numbers
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
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end