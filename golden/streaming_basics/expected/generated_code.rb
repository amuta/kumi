module SchemaModule
  # Generated code with pack hash: 296637f7392a2d64b6e45cd73dc400e92cd93080023d5b1719bbd5225a52fabd:ae595c9e79348d4e6b1775c779651b3bbbe3aa9cd532ccfc63f685678fa22fa5:1f5efccd8b84b9f6d92fe394203a09051c2104ebeb731420e12495eb44129801

  def _each_items_subtotal
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      v0 = a0["price"]
      v1 = a0["qty"]
      v2 = __call_kernel__("core.mul", v0, v1)
      yield v2, [i0]
    end
  end

  def _eval_items_subtotal
    __materialize_from_each(:items_subtotal)
  end

  def _each_items_discounted
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      c1 = 1.0
      v2 = a0["discount"]
      v3 = __call_kernel__("core.sub", v1, v2)
      v0 = a0["price"]
      v4 = __call_kernel__("core.mul", v0, v3)
      yield v4, [i0]
    end
  end

  def _eval_items_discounted
    __materialize_from_each(:items_discounted)
  end

  def _each_items_is_big
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      c1 = 100.0
      v0 = a0["price"]
      v2 = __call_kernel__("core.gt", v0, v1)
      yield v2, [i0]
    end
  end

  def _eval_items_is_big
    __materialize_from_each(:items_is_big)
  end

  def _each_items_effective
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      c2 = 0.9
      v0_items_subtotal = a0["price"]
      v1_items_subtotal = a0["qty"]
      v1 = __call_kernel__("core.mul", v0_items_subtotal, v1_items_subtotal)
      v3 = __call_kernel__("core.mul", v1, v2)
      citems_is_big_1 = 100.0
      v0_items_is_big = a0["price"]
      v0 = __call_kernel__("core.gt", v0_items_is_big, citems_is_big_1)
      v5 = (v0 ? v3 : v1)
      yield v5, [i0]
    end
  end

  def _eval_items_effective
    __materialize_from_each(:items_effective)
  end

  def _each_total_qty
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      acc_1 = 0.0
      v0 = a0["qty"]
      acc_1 += v0
      v1 = acc_1
      yield v1, []
    end
  end

  def _eval_total_qty
    _each_total_qty { |value, _| return value }
  end

  def _each_cart_total
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      acc_1 = 0.0
      acc_1 += v0
      v1 = acc_1
      yield v1, []
    end
  end

  def _eval_cart_total
    _each_cart_total { |value, _| return value }
  end

  def _each_cart_total_effective
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      acc_1 = 0.0
      acc_1 += v0
      v1 = acc_1
      yield v1, []
    end
  end

  def _eval_cart_total_effective
    _each_cart_total_effective { |value, _| return value }
  end

  def [](name)
    case name
    when :items_subtotal then _eval_items_subtotal
    when :items_discounted then _eval_items_discounted
    when :items_is_big then _eval_items_is_big
    when :items_effective then _eval_items_effective
    when :total_qty then _eval_total_qty
    when :cart_total then _eval_cart_total
    when :cart_total_effective then _eval_cart_total_effective
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
    return (->(a, b) { a - b }).call(*args) if id == "core.sub"
    return (->(a, b) { a > b }).call(*args) if id == "core.gt"
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end