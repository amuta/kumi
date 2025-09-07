module SchemaModule
  # Generated code with pack hash: d8833d4cf5e7a490cb6cdefc47365ddc6c29b932547098d4e155b65f2f841a36:52ee61a5b425c9f5fdfddeb50014cbbf865f202dc79538f8a29fd7c14b4353ee:1b3d6b8d2d890e166184b49c147df84d1bdd65f8a9e3b824b8d4bd69912415f5

  def _each_numbers_mult_10
    arr0 = @input["array_of_arrays"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        arr2 = a1["array_field"]
        arr2.each_with_index do |a2, i2|
          arr3 = a2["array_field_two"]
          arr3.each_with_index do |a3, i3|
            op0 = a3
            op2 = __call_kernel__("core.mul", op0, 10)
            yield op2, [i0, i1, i2, i3]
          end
        end
      end
    end
  end

  def _eval_numbers_mult_10
    __materialize_from_each(:numbers_mult_10)
  end

  def _each_sum_of_nums
    arr0 = @input["array_of_arrays"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0
      arr1.each_with_index do |a1, i1|
        arr2 = a1["array_field"]
        arr2.each_with_index do |a2, i2|
          arr3 = a2["array_field_two"]
          arr3.each_with_index do |a3, i3|
            acc_4 = 0
            op3 = self[:numbers_mult_10][i0][i1][i2][i3]
            acc_4 = __call_kernel__("agg.sum", acc_4, op3)
            op4 = acc_4
            yield op4, [i0, i1, i2]
          end
        end
      end
    end
  end

  def _eval_sum_of_nums
    __materialize_from_each(:sum_of_nums)
  end

  def [](name)
    case name
    when :numbers_mult_10 then _eval_numbers_mult_10
    when :sum_of_nums then _eval_sum_of_nums
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
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end