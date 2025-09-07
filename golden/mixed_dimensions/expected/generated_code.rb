module SchemaModule
  # Generated code with pack hash: af979b2df7c43ac3d200cf659d69e1cad807ccea8c10586e3b9678176ede1570:61186f2f35c20885abb46e7ede39e93f3129991e3e7e5ce82e5c8aabd1547fc6:e40a033b041677d70aebdf20c4c7c92865624d829df178039f889281c5599f97

  def _each_sum_numbers
    acc_1 = 0.0
    arr0 = @input["numbers"]
    arr0.each_with_index do |a0, i0|
      op0 = a0["value"]
      acc_1 = __call_kernel__("agg.sum", acc_1, op0)
    end
    op1 = acc_1
    yield op1, []
  end

  def _eval_sum_numbers
    _each_sum_numbers { |value, _| return value }
  end

  def _each_matrix_sums
    arr0 = @input["matrix"]
    arr0.each_with_index do |a0, i0|
      acc_3 = 0.0
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
        op2 = a1["cell"]
        acc_3 = __call_kernel__("agg.sum", acc_3, op2)
      end
      op3 = acc_3
      yield op3, [i0]
    end
  end

  def _eval_matrix_sums
    __materialize_from_each(:matrix_sums)
  end

  def _each_mixed_array
    op4 = @input["scalar_val"]
    op5 = self[:sum_numbers]
    arr0 = @input["matrix"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
        op6 = a1["cell"]
        op7 = [op4, op5, op6]
        yield op7, [i0, i1]
      end
    end
  end

  def _eval_mixed_array
    __materialize_from_each(:mixed_array)
  end

  def _each_constant
    op8 = 42
    yield op8, []
  end

  def _eval_constant
    _each_constant { |value, _| return value }
  end

  def [](name)
    case name
    when :sum_numbers then _eval_sum_numbers
    when :matrix_sums then _eval_matrix_sums
    when :mixed_array then _eval_mixed_array
    when :constant then _eval_constant
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
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end