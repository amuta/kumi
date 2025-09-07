module SchemaModule
  # Generated code with pack hash: 296637f7392a2d64b6e45cd73dc400e92cd93080023d5b1719bbd5225a52fabd:0065cea481626dd245da306711ccd3d7dc0221e2e08c9411b0f2df2392eec532:b9e4074d49d7ca69e75cbca2aecdf8486b7c7561aa94589571137289855e33bf

  def _each_items_subtotal
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      op0 = a0["price"]
      op1 = a0["qty"]
      op2 = __call_kernel__("core.mul", op0, op1)
      yield op2, [i0]
    end
  end

  def _eval_items_subtotal
    __materialize_from_each(:items_subtotal)
  end

  def _each_items_discounted
    op4 = 1.0
    op5 = @input["discount"]
    op6 = __call_kernel__("core.sub", 1.0, op5)
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      op3 = a0["price"]
      op7 = __call_kernel__("core.mul", op3, op6)
      yield op7, [i0]
    end
  end

  def _eval_items_discounted
    __materialize_from_each(:items_discounted)
  end

  def _each_items_is_big
    op9 = 100.0
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      op8 = a0["price"]
      op10 = __call_kernel__("core.gt", op8, 100.0)
      yield op10, [i0]
    end
  end

  def _eval_items_is_big
    __materialize_from_each(:items_is_big)
  end

  def _each_items_effective
    op13 = 0.9
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      op11 = self[:items_is_big][i0]
      op12 = self[:items_subtotal][i0]
      op14 = __call_kernel__("core.mul", op12, 0.9)
      op15 = self[:items_subtotal][i0]
      op16 = (op11 ? op14 : op15)
      yield op16, [i0]
    end
  end

  def _eval_items_effective
    __materialize_from_each(:items_effective)
  end

  def _each_total_qty
    acc_18 = 0.0
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      op17 = a0["qty"]
      acc_18 = __call_kernel__("agg.sum", acc_18, op17)
    end
    op18 = acc_18
    yield op18, []
  end

  def _eval_total_qty
    _each_total_qty { |value, _| return value }
  end

  def _each_cart_total
    acc_20 = 0.0
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      op19 = self[:items_subtotal][i0]
      acc_20 = __call_kernel__("agg.sum", acc_20, op19)
    end
    op20 = acc_20
    yield op20, []
  end

  def _eval_cart_total
    _each_cart_total { |value, _| return value }
  end

  def _each_cart_total_effective
    acc_22 = 0.0
    arr0 = @input["items"]
    arr0.each_with_index do |a0, i0|
      op21 = self[:items_effective][i0]
      acc_22 = __call_kernel__("agg.sum", acc_22, op21)
    end
    op22 = acc_22
    yield op22, []
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