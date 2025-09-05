module SchemaModule
  # Generated code with pack hash: c406bb9647341a983c42cbeeb22c96ef2e2074a5643637f120bf644d89a1b8ee:69bcee137c17ba3ef86a34a9954ffab24d48e6c84189bfe9f1e024ea4a9c1c22:234af5166ea4222d549ed45b78f10f1793c5508e7a0f8e3c2c07a97c62eec919

  def _each_y_positive
    c1 = 0
    v0 = @input["y"]
    v2 = __call_kernel__("core.gt", v0, c1)
    yield v2, []
  end

  def _eval_y_positive
    _each_y_positive { |value, _| return value }
  end

  def _each_x_positive
    c1 = 0
    v0 = @input["x"]
    v2 = __call_kernel__("core.gt", v0, c1)
    yield v2, []
  end

  def _eval_x_positive
    _each_x_positive { |value, _| return value }
  end

  def _each_status
  v0_y_positive = @input["y"]
  cy_positive_1 = 0
  v0 = __call_kernel__("core.gt", v0_y_positive, cy_positive_1)
  v0_x_positive = @input["x"]
  cx_positive_1 = 0
  v1 = __call_kernel__("core.gt", v0_x_positive, cx_positive_1)
    c3 = "both positive"
    c5 = "x positive"
    c7 = "y positive"
    c8 = "neither positive"
    v2 = __call_kernel__("core.and", v0_x_positive, cx_positive_1)
    v9 = (v0_x_positive ? c7 : c8)
    v10 = (cx_positive_1 ? c5 : v9)
    v11 = (v1 ? c3 : v10)
    yield v11, []
  end

  def _eval_status
    _each_status { |value, _| return value }
  end

  def [](name)
    case name
    when :y_positive then _eval_y_positive
    when :x_positive then _eval_x_positive
    when :status then _eval_status
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
    return (->(a, b) { a && b }).call(*args) if id == "core.and"
    raise KeyError, "Unknown kernel: #{id}"
  end
end