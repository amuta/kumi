module SchemaModule
  # Generated code with pack hash: 296637f7392a2d64b6e45cd73dc400e92cd93080023d5b1719bbd5225a52fabd:a8a3867b1e4474ca045ad647f1628b32a8f0fc82509da1eb3f6ed2d48de4ef0f:71094081f55c7aa2aae6462fdc0153ab997138d549724a490e9babc81d1764b4

  def _each_cart_total
    # TODO: Implement streaming method for cart_total
    acc_1 = 0.0
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      v0 = self[:items_subtotal][i0]
      acc_1 += v0
      i0 += 1
    end
    v1 = acc_1
    yield v1, [i0]
  end

  def _eval_cart_total
    # TODO: Implement materialization for cart_total
    __materialize_from_each(:cart_total)
  end

  def _each_cart_total_effective
    # TODO: Implement streaming method for cart_total_effective
    acc_1 = 0.0
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      v0 = self[:items_effective][i0]
      acc_1 += v0
      i0 += 1
    end
    v1 = acc_1
    yield v1, [i0]
  end

  def _eval_cart_total_effective
    # TODO: Implement materialization for cart_total_effective
    __materialize_from_each(:cart_total_effective)
  end

  def _each_items_discounted
    # TODO: Implement streaming method for items_discounted
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    c1 = 1.0
    c1 = 1.0
    v2 = @input["discount"]
    v3 = __call_kernel__("core.sub", c1, v2)
      v0 = a0["price"]
      v4 = __call_kernel__("core.mul", v0, v3)
      yield v4, [i0]
      i0 += 1
    end
  end

  def _eval_items_discounted
    # TODO: Implement materialization for items_discounted
    __materialize_from_each(:items_discounted)
  end

  def _each_items_effective
    # TODO: Implement streaming method for items_effective
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    c2 = 0.9
    c2 = 0.9
      v0 = self[:items_is_big][i0]
      v1 = self[:items_subtotal][i0]
      v3 = __call_kernel__("core.mul", v1, c2)
      v5 = (v0 ? v3 : v1)
      yield v5, [i0]
      i0 += 1
    end
  end

  def _eval_items_effective
    # TODO: Implement materialization for items_effective
    __materialize_from_each(:items_effective)
  end

  def _each_items_is_big
    # TODO: Implement streaming method for items_is_big
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

  def _eval_items_is_big
    # TODO: Implement materialization for items_is_big
    __materialize_from_each(:items_is_big)
  end

  def _each_items_subtotal
    # TODO: Implement streaming method for items_subtotal
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      v0 = a0["price"]
      v1 = a0["qty"]
      v2 = __call_kernel__("core.mul", v0, v1)
      yield v2, [i0]
      i0 += 1
    end
  end

  def _eval_items_subtotal
    # TODO: Implement materialization for items_subtotal
    __materialize_from_each(:items_subtotal)
  end

  def _each_total_qty
    # TODO: Implement streaming method for total_qty
    acc_1 = 0.0
    arr0 = @input["items"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      v0 = a0["qty"]
      acc_1 += v0
      i0 += 1
    end
    v1 = acc_1
    yield v1, []
  end

  def _eval_total_qty
    # TODO: Implement materialization for total_qty
    _each_total_qty { |value, _| return value }
  end

  def [](name)
    case name
    when :cart_total then _eval_cart_total
    when :cart_total_effective then _eval_cart_total_effective
    when :items_discounted then _eval_items_discounted
    when :items_effective then _eval_items_effective
    when :items_is_big then _eval_items_is_big
    when :items_subtotal then _eval_items_subtotal
    when :total_qty then _eval_total_qty
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
    return (->(a, b) { a - b }).call(*args) if id == "core.sub"
    return (->(a, b) { a > b }).call(*args) if id == "core.gt"
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end