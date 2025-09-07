module SchemaModule
  # Generated code with pack hash: e82ce420cfa0ce124f4aaac6453a303dd0c4c1ac814c8325b4d046c89fead22d:30de2c4af6ef7a11d77747b70053e8a11cf817e2733402f6649d7cdff096800d:e796fed854d71d3f76f81b3813070d7fb1be2701639fa247cc5cb234ebb20648

  def _each_sum
    op0 = @input["x"]
    op1 = @input["y"]
    op2 = __call_kernel__("core.add", op0, op1)
    yield op2, []
  end

  def _eval_sum
    _each_sum { |value, _| return value }
  end

  def _each_product
    op3 = @input["x"]
    op4 = @input["y"]
    op5 = __call_kernel__("core.mul", op3, op4)
    yield op5, []
  end

  def _eval_product
    _each_product { |value, _| return value }
  end

  def _each_difference
    op6 = @input["x"]
    op7 = @input["y"]
    op8 = __call_kernel__("core.sub", op6, op7)
    yield op8, []
  end

  def _eval_difference
    _each_difference { |value, _| return value }
  end

  def _each_results_array
    op9 = 1
    op10 = @input["x"]
    op11 = 10
    op12 = __call_kernel__("core.add", op10, 10)
    op13 = @input["y"]
    op14 = 2
    op15 = __call_kernel__("core.mul", op13, 2)
    op16 = [1, op12, op15]
    yield op16, []
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