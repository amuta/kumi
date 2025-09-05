module SchemaModule
  # Generated code with pack hash: e82ce420cfa0ce124f4aaac6453a303dd0c4c1ac814c8325b4d046c89fead22d:9a9b1f0ef0fbe709b79cd778cd1e138f216c0b9c5781a129b15d91931656d11b:e796fed854d71d3f76f81b3813070d7fb1be2701639fa247cc5cb234ebb20648

  def _each_sum
    v0 = @input["x"]
    v1 = @input["y"]
    v2 = __call_kernel__("core.add", v0, v1)
    yield v2, []
  end

  def _eval_sum
    _each_sum { |value, _| return value }
  end

  def _each_product
    v0 = @input["x"]
    v1 = @input["y"]
    v2 = __call_kernel__("core.mul", v0, v1)
    yield v2, []
  end

  def _eval_product
    _each_product { |value, _| return value }
  end

  def _each_difference
    v0 = @input["x"]
    v1 = @input["y"]
    v2 = __call_kernel__("core.sub", v0, v1)
    yield v2, []
  end

  def _eval_difference
    _each_difference { |value, _| return value }
  end

  def _each_results_array
    c0 = 1
    c2 = 10
    c5 = 2
    v1 = @input["x"]
    v3 = __call_kernel__("core.add", v1, c2)
    v4 = @input["y"]
    v6 = __call_kernel__("core.mul", v4, c5)
    v7 = [c0, v3, v6]
    yield v7, []
  end

  def _eval_results_array
    _each_results_array { |value, _| return value }
  end

  def [](name)
    case name
    when :sum then _eval_sum
    when :product then _eval_product
    when :difference then _eval_difference
    when :results_array then _eval_results_array
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
    return (->(a, b) { a + b }).call(*args) if id == "core.add"
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    return (->(a, b) { a - b }).call(*args) if id == "core.sub"
    raise KeyError, "Unknown kernel: #{id}"
  end
end