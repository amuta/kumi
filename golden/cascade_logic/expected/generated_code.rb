module SchemaModule
  # Generated code with pack hash: c406bb9647341a983c42cbeeb22c96ef2e2074a5643637f120bf644d89a1b8ee:bea871ac23bbfb6140801504a47a46ec248f50f184d28a76c3e2b19ccf843635:234af5166ea4222d549ed45b78f10f1793c5508e7a0f8e3c2c07a97c62eec919

  def _each_status
    # TODO: Implement streaming method for status
    c3 = "both positive"
    c5 = "x positive"
    c7 = "y positive"
    c8 = "neither positive"
    v0 = self[:y_positive]
    v1 = self[:x_positive]
    v2 = __call_kernel__("core.and", v0, v1)
    c3 = "both positive"
    c5 = "x positive"
    c7 = "y positive"
    c8 = "neither positive"
    v9 = (v0 ? c7 : c8)
    v10 = (v1 ? c5 : v9)
    v11 = (v2 ? c3 : v10)
    yield v11, []
  end

  def _eval_status
    # TODO: Implement materialization for status
    _each_status { |value, _| return value }
  end

  def _each_x_positive
    # TODO: Implement streaming method for x_positive
    c1 = 0
    v0 = @input["x"]
    c1 = 0
    v2 = __call_kernel__("core.gt", v0, c1)
    yield v2, []
  end

  def _eval_x_positive
    # TODO: Implement materialization for x_positive
    _each_x_positive { |value, _| return value }
  end

  def _each_y_positive
    # TODO: Implement streaming method for y_positive
    c1 = 0
    v0 = @input["y"]
    c1 = 0
    v2 = __call_kernel__("core.gt", v0, c1)
    yield v2, []
  end

  def _eval_y_positive
    # TODO: Implement materialization for y_positive
    _each_y_positive { |value, _| return value }
  end

  def [](name)
    case name
    when :status then _eval_status
    when :x_positive then _eval_x_positive
    when :y_positive then _eval_y_positive
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
    return (->(a, b) { a && b }).call(*args) if id == "core.and"
    raise KeyError, "Unknown kernel: #{id}"
  end
end