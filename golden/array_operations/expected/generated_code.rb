module SchemaModule
  # Generated code with pack hash: 4d099f0fb984b4068ae7d12c14f5913a796f2076a0bb52660683ecad6e8d87c2:5fd4d793f2d8c7966436da0c79ddb59704f27ff6827b5dad3e5189c3df4fa5e7:5ceabfc168da0f10c91bd811df22d4716956b61ca06a1816b9a880c0be5ba011

  def _each_discounted_price
    # TODO: Implement streaming method for discounted_price
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    c1 = 0.9
    c1 = 0.9
      v0 = a0["price"]
      v2 = __call_kernel__("core.mul", v0, c1)
      yield v2, [i0]
      i0 += 1
    end
  end

  def _eval_discounted_price
    # TODO: Implement materialization for discounted_price
    __materialize_from_each(:discounted_price)
  end

  def _each_electronics
    # TODO: Implement streaming method for electronics
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    c1 = "electronics"
    c1 = "electronics"
      v0 = a0["category"]
      v2 = __call_kernel__("core.eq", v0, c1)
      yield v2, [i0]
      i0 += 1
    end
  end

  def _eval_electronics
    # TODO: Implement materialization for electronics
    __materialize_from_each(:electronics)
  end

  def _each_expensive_items
    # TODO: Implement streaming method for expensive_items
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    c1 = 100.0
    c1 = 100.0
      v0 = a0["price"]
      v2 = __call_kernel__("core.gt", v0, c1)
      yield v2, [i0]
      i0 += 1
    end
  end

  def _eval_expensive_items
    # TODO: Implement materialization for expensive_items
    __materialize_from_each(:expensive_items)
  end

  def _each_is_valid_quantity
    # TODO: Implement streaming method for is_valid_quantity
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    c1 = 0
    c1 = 0
      v0 = a0["quantity"]
      v2 = __call_kernel__("core.gt", v0, c1)
      yield v2, [i0]
      i0 += 1
    end
  end

  def _eval_is_valid_quantity
    # TODO: Implement materialization for is_valid_quantity
    __materialize_from_each(:is_valid_quantity)
  end

  def _each_subtotals
    # TODO: Implement streaming method for subtotals
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      v0 = a0["price"]
      v1 = a0["quantity"]
      v2 = __call_kernel__("core.mul", v0, v1)
      yield v2, [i0]
      i0 += 1
    end
  end

  def _eval_subtotals
    # TODO: Implement materialization for subtotals
    __materialize_from_each(:subtotals)
  end

  def [](name)
    case name
    when :discounted_price then _eval_discounted_price
    when :electronics then _eval_electronics
    when :expensive_items then _eval_expensive_items
    when :is_valid_quantity then _eval_is_valid_quantity
    when :subtotals then _eval_subtotals
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
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    return (->(a, b) { a > b }).call(*args) if id == "core.gt"
    return (->(a, b) { a == b }).call(*args) if id == "core.eq"
    raise KeyError, "Unknown kernel: #{id}"
  end
end