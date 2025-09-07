module SchemaModule
  # Generated code with pack hash: c406bb9647341a983c42cbeeb22c96ef2e2074a5643637f120bf644d89a1b8ee:46020f905d6533b2ca10164444dcfd6aba1d9157ec57511e75edc8c99a23e0e8:e796fed854d71d3f76f81b3813070d7fb1be2701639fa247cc5cb234ebb20648

  def _each_y_positive
    op0 = @input["y"]
    op2 = __call_kernel__("core.gt", op0, 0)
    yield op2, []
  end

  def _eval_y_positive
    _each_y_positive { |value, _| return value }
  end

  def _each_x_positive
    op3 = @input["x"]
    op5 = __call_kernel__("core.gt", op3, 0)
    yield op5, []
  end

  def _eval_x_positive
    _each_x_positive { |value, _| return value }
  end

  def _each_status
    op6 = self[:y_positive]
    op7 = self[:x_positive]
    op8 = __call_kernel__("core.and", op6, op7)
    op10 = self[:x_positive]
    op12 = self[:y_positive]
    op15 = (op12 ? "y positive" : "neither positive")
    op16 = (op10 ? "x positive" : op15)
    op17 = (op8 ? "both positive" : op16)
    yield op17, []
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