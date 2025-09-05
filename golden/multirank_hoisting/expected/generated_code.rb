module SchemaModule
  # Generated code with pack hash: 3348fb476948c6dbfbe8fb9cbb7885960f977aa579780d139c16a92351c2d49f:417f573f8845c655e31454a5abf3fe4df95325b50360e6a1cb076911a1760002:9d85bf516b106dd0565ab16047155264e04cbd968f14abf38d5740091915f835

  def _each_global_offset_plus
    c1 = 1.0
    v0 = @input["global_offset"]
    v2 = __call_kernel__("core.add", v0, c1)
    yield v2, []
  end

  def _eval_global_offset_plus
    _each_global_offset_plus { |value, _| return value }
  end

  def _each_batch_bias
  v0_global_offset_plus = @input["global_offset"]
  cglobal_offset_plus_1 = 1.0
  v1 = __call_kernel__("core.add", v0_global_offset_plus, cglobal_offset_plus_1)
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
      v0 = a0["mean"]
      v2 = __call_kernel__("core.add", v0_global_offset_plus, cglobal_offset_plus_1)
      yield v2, [i0]
    end
  end

  def _eval_batch_bias
    __materialize_from_each(:batch_bias)
  end

  def _each_row_scale2
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
    c1 = 2.0
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
        v0 = a1["scale"]
        v2 = __call_kernel__("core.mul", v0, c1)
        yield v2, [i0, i1]
      end
    end
  end

  def _eval_row_scale2
    __materialize_from_each(:row_scale2)
  end

  def _each_elem_affine
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
    v0_batch_bias = a0["mean"]
    v3 = __call_kernel__("core.add", v0_batch_bias, v1_batch_bias)
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
      crow_scale2_1 = 2.0
      v0_row_scale2 = a1["scale"]
      v1 = __call_kernel__("core.mul", v0_row_scale2, crow_scale2_1)
        arr2 = a1["col"]
        arr2.each_with_index do |a2, i2|
          v0 = a2["val"]
          v2 = __call_kernel__("core.mul", v0_row_scale2, crow_scale2_1)
          v4 = __call_kernel__("core.add", v1, v3)
          yield v4, [i0, i1, i2]
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
        acc_1 = 0.0
        v0_elem_affine = a2["val"]
        v2_elem_affine = __call_kernel__("core.mul", v0_elem_affine, v1_elem_affine)
        v0 = __call_kernel__("core.add", v2_elem_affine, v3_elem_affine)
          acc_1 += v0
        v1 = acc_1
        yield v1, [i0, i1]
      end
    end
  end

  def _eval_row_sum_affine
    __materialize_from_each(:row_sum_affine)
  end

  def _each_batch_total_affine
    arr0 = @input["batch"]
    arr0.each_with_index do |a0, i0|
      acc_1 = 0.0
        acc_1 += v0
      v1 = acc_1
      yield v1, [i0]
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