module SchemaModule
  # Generated code with pack hash: e82ce420cfa0ce124f4aaac6453a303dd0c4c1ac814c8325b4d046c89fead22d:d6a386ad5f8ea66f802a7e8f8307c7e72f589c4842f9a068e95806a4be7fca76:234af5166ea4222d549ed45b78f10f1793c5508e7a0f8e3c2c07a97c62eec919

  def _each_difference
    # TODO: Implement streaming method for difference
    v0 = @input["x"]
    v1 = @input["y"]
    v2 = __call_kernel__("core.sub", v0, v1)
    yield v2, []
  end

  def _eval_difference
    # TODO: Implement materialization for difference
    _each_difference { |value, _| return value }
  end

  def _each_product
    # TODO: Implement streaming method for product
    v0 = @input["x"]
    v1 = @input["y"]
    v2 = __call_kernel__("core.mul", v0, v1)
    yield v2, []
  end

  def _eval_product
    # TODO: Implement materialization for product
    _each_product { |value, _| return value }
  end

  def _each_results_array
    # TODO: Implement streaming method for results_array
    c0 = 1
    c2 = 10
    c5 = 2
    c0 = 1
    v1 = @input["x"]
    c2 = 10
    v3 = __call_kernel__("core.add", v1, c2)
    v4 = @input["y"]
    c5 = 2
    v6 = __call_kernel__("core.mul", v4, c5)
    v7 = self[:product]
    v8 = [c0, v3, v6, v7]
    yield v8, []
  end

  def _eval_results_array
    # TODO: Implement materialization for results_array
    _each_results_array { |value, _| return value }
  end

  def _each_sum
    # TODO: Implement streaming method for sum
    v0 = @input["x"]
    v1 = @input["y"]
    v2 = __call_kernel__("core.add", v0, v1)
    yield v2, []
  end

  def _eval_sum
    # TODO: Implement materialization for sum
    _each_sum { |value, _| return value }
  end

  def [](name)
    case name
    when :difference then _eval_difference
    when :product then _eval_product
    when :results_array then _eval_results_array
    when :sum then _eval_sum
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
    return (->(a, b) { a + b }).call(*args) if id == "core.add"
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    return (->(a, b) { a - b }).call(*args) if id == "core.sub"
    raise KeyError, "Unknown kernel: #{id}"
  end
end