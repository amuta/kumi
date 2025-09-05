module SchemaModule
  # Generated code with pack hash: 4d099f0fb984b4068ae7d12c14f5913a796f2076a0bb52660683ecad6e8d87c2:522678faa3f8a3926790d8675952576a0ce39f762bc69d6c9460328de5c65ab6:c6742dd495cd8b9cbf67522bd376b4136c7fbebc5b0f2fa0114761f3bab99218

  def _each_subtotals
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      v0 = a0["price"]
      v1 = a0["quantity"]
      v2 = __call_kernel__("core.mul", v0, v1)
      yield v2, []
    end
  end

  def _eval_subtotals
    _each_subtotals { |value, _| return value }
  end

  def _each_discounted_price
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      c1 = 0.9
      v0 = a0["price"]
      v2 = __call_kernel__("core.mul", v0, c1)
      yield v2, []
    end
  end

  def _eval_discounted_price
    _each_discounted_price { |value, _| return value }
  end

  def _each_is_valid_quantity
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      c1 = 0
      v0 = a0["quantity"]
      v2 = __call_kernel__("core.gt", v0, c1)
      yield v2, []
    end
  end

  def _eval_is_valid_quantity
    _each_is_valid_quantity { |value, _| return value }
  end

  def _each_expensive_items
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      c1 = 100.0
      v0 = a0["price"]
      v2 = __call_kernel__("core.gt", v0, c1)
      yield v2, []
    end
  end

  def _eval_expensive_items
    _each_expensive_items { |value, _| return value }
  end

  def _each_electronics
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      c1 = "electronics"
      v0 = a0["category"]
      v2 = __call_kernel__("core.eq", v0, c1)
      yield v2, []
    end
  end

  def _eval_electronics
    _each_electronics { |value, _| return value }
  end

  def [](name)
    case name
    when :subtotals then _eval_subtotals
    when :discounted_price then _eval_discounted_price
    when :is_valid_quantity then _eval_is_valid_quantity
    when :expensive_items then _eval_expensive_items
    when :electronics then _eval_electronics
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
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    return (->(a, b) { a > b }).call(*args) if id == "core.gt"
    return (->(a, b) { a == b }).call(*args) if id == "core.eq"
    raise KeyError, "Unknown kernel: #{id}"
  end
end