module SchemaModule
  # Generated code with pack hash: af979b2df7c43ac3d200cf659d69e1cad807ccea8c10586e3b9678176ede1570:9fbed8645daf7197b2aef75a78aae1b9ed4a6300c020df7adfe9af51c07406fd:23c781957560f94848c3da53598d334cef855744d1a39393729391e849ca9288

  def _each_sum_numbers
    arr0 = @input["numbers"]
    arr0.each_with_index do |a0, i0|
      acc_1 = 0.0
      v0 = a0["value"]
      acc_1 += v0
      v1 = acc_1
      yield v1, []
    end
  end

  def _eval_sum_numbers
    _each_sum_numbers { |value, _| return value }
  end

  def _each_matrix_sums
    arr0 = @input["matrix"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["row"]
      arr1.each_with_index do |a1, i1|
        acc_1 = 0.0
        v0 = a1["cell"]
        acc_1 += v0
        v1 = acc_1
        yield v1, [i0]
      end
    end
  end

  def _eval_matrix_sums
    __materialize_from_each(:matrix_sums)
  end

  def _each_mixed_array
    v0 = @input["scalar_val"]
    v2 = @input["matrix"]["row"]["cell"]
    v3 = [v0, v1, v2]
    yield v3, []
  end

  def _eval_mixed_array
    _each_mixed_array { |value, _| return value }
  end

  def _each_constant
    c0 = 42
    yield v0, []
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