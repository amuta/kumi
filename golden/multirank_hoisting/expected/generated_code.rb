module SchemaModule
  # Generated code with pack hash: 3348fb476948c6dbfbe8fb9cbb7885960f977aa579780d139c16a92351c2d49f:c70bbd4a656eddc8b941749de0127730b4752836473e40504ab492c67fb7b826:dc52d1036aaceb1197706f9d0209700eb1b0a4cacb7264f6e541fb66fc603f7e

  def _each_global_offset_plus
    op0 = @input["global_offset"]
    op2 = __call_kernel__("core.add", op0, 1.0)
    yield op2, []
  end

  def _eval_global_offset_plus
    _each_global_offset_plus { |value, _| return value }
  end

  def _each_batch_bias
    op4 = self[:global_offset_plus]
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
      op3 = a0["mean"]
      op5 = __call_kernel__("core.add", op3, op4)
      yield op5, [i0]
    end
  end

  def _eval_batch_bias
    __materialize_from_each(:batch_bias)
  end

  def _each_row_scale2
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
        op6 = a1["scale"]
        op8 = __call_kernel__("core.mul", op6, 2.0)
        yield op8, [i0, i1]
      end
    end
  end

  def _eval_row_scale2
    __materialize_from_each(:row_scale2)
  end

  def _each_elem_affine
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
        op12 = self[:batch_bias][i0]
        arr2 = a1["col"]
        arr2.each_with_index do |a2, i2|
          op10 = self[:row_scale2][i0][i1]
          op9 = a2["val"]
          op11 = __call_kernel__("core.mul", op9, op10)
          op13 = __call_kernel__("core.add", op11, op12)
          yield op13, [i0, i1, i2]
        end
      end
    end
  end

  def _eval_elem_affine
    __materialize_from_each(:elem_affine)
  end

  def _each_row_sum_affine
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["col"]
        arr2.each_with_index do |a2, i2|
          acc_15 = 0.0
          op14 = self[:elem_affine][i0][i1][i2]
          acc_15 = __call_kernel__("agg.sum", acc_15, op14)
          op15 = acc_15
          yield op15, [i0, i1]
        end
      end
    end
  end

  def _eval_row_sum_affine
    __materialize_from_each(:row_sum_affine)
  end

  def _each_batch_total_affine
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
      op16 = self[:row_sum_affine][i0][i1]
      acc_17 = 0.0
      acc_17 = __call_kernel__("agg.sum", acc_17, op16)
      op17 = acc_17
      yield op17, [i0]
    end
  end

  def _eval_batch_total_affine
    __materialize_from_each(:batch_total_affine)
  end

  def [](name)
    case name
    when :global_offset_plus then _eval_global_offset_plus
    when :batch_bias then _eval_batch_bias
    when :row_scale2 then _eval_row_scale2
    when :elem_affine then _eval_elem_affine
    when :row_sum_affine then _eval_row_sum_affine
    when :batch_total_affine then _eval_batch_total_affine
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
    return (->(a, b) { a + b }).call(*args) if id == "core.add"
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end