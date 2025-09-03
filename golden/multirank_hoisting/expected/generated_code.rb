module SchemaModule
  # Generated code with pack hash: 3348fb476948c6dbfbe8fb9cbb7885960f977aa579780d139c16a92351c2d49f:4acfcf93dbb084853037804511a2041f2c6dd4dd4184b1428f98a09a843ccadd:9d85bf516b106dd0565ab16047155264e04cbd968f14abf38d5740091915f835

  def _each_batch_bias
    # TODO: Implement streaming method for batch_bias
    arr0 = @input["batch"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    v1 = self[:global_offset_plus]
      v0 = a0["mean"]
      v2 = __call_kernel__("core.add", v0, v1)
      yield v2, []
      i0 += 1
    end
  end

  def _eval_batch_bias
    # TODO: Implement materialization for batch_bias
    _each_batch_bias { |value, _| return value }
  end

  def _each_batch_total_affine
    # TODO: Implement streaming method for batch_total_affine
      acc_1 = 0.0
    arr0 = @input["batch"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      yield v1, [i0, i1]
        v0 = self[:row_sum_affine][i0][i1]
        acc_1 += v0
      i0 += 1
    end
      v1 = acc_1
  end

  def _eval_batch_total_affine
    # TODO: Implement materialization for batch_total_affine
    __materialize_from_each(:batch_total_affine)
  end

  def _each_elem_affine
    # TODO: Implement streaming method for elem_affine
    arr0 = @input["batch"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["row"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["col"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
      v3 = self[:batch_bias][i0]
        v1 = self[:row_scale2][i0][i1]
          v0 = a2["val"]
          v2 = __call_kernel__("core.mul", v0, v1)
          v4 = __call_kernel__("core.add", v2, v3)
          yield v4, [i0, i1]
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_elem_affine
    # TODO: Implement materialization for elem_affine
    __materialize_from_each(:elem_affine)
  end

  def _each_global_offset_plus
    # TODO: Implement streaming method for global_offset_plus
    c1 = 1.0
    v0 = @input["global_offset"]
    c1 = 1.0
    v2 = __call_kernel__("core.add", v0, c1)
    yield v2, []
  end

  def _eval_global_offset_plus
    # TODO: Implement materialization for global_offset_plus
    _each_global_offset_plus { |value, _| return value }
  end

  def _each_row_scale2
    # TODO: Implement streaming method for row_scale2
    arr0 = @input["batch"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["row"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
    c1 = 2.0
    c1 = 2.0
        v0 = a1["scale"]
        v2 = __call_kernel__("core.mul", v0, c1)
        yield v2, [i0, i1]
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_row_scale2
    # TODO: Implement materialization for row_scale2
    __materialize_from_each(:row_scale2)
  end

  def _each_row_sum_affine
    # TODO: Implement streaming method for row_sum_affine
        acc_1 = 0.0
    arr0 = @input["batch"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["row"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        yield v1, [i0, i1, i2]
          v0 = self[:elem_affine][i0][i1][i2]
          acc_1 += v0
        i1 += 1
      end
      i0 += 1
    end
        v1 = acc_1
  end

  def _eval_row_sum_affine
    # TODO: Implement materialization for row_sum_affine
    __materialize_from_each(:row_sum_affine)
  end

  def [](name)
    case name
    when :batch_bias then _eval_batch_bias
    when :batch_total_affine then _eval_batch_total_affine
    when :elem_affine then _eval_elem_affine
    when :global_offset_plus then _eval_global_offset_plus
    when :row_scale2 then _eval_row_scale2
    when :row_sum_affine then _eval_row_sum_affine
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
    return (->(a, b) { a + b }).call(*args) if id == "core.add"
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    raise KeyError, "Unknown kernel: #{id}"
  end
end