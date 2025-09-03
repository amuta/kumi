module SchemaModule
  # Generated code with pack hash: afe16a37162e4b64766c1e62c9335166e1ff9d711f3380ef32a06de5d4da1ae4:e2529508629293c6058f26391d4bbc4fb9485a1bcc91b54606f78e4a3d44d86a:95ccb7df5aadfc90e63b52740208a475b02424743078f5fd761d988c405d0252

  def _each_big_team
    # TODO: Implement streaming method for big_team
    arr0 = @input["depts"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["teams"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
    c1 = 10
    c1 = 10
        v0 = a1["headcount"]
        v2 = __call_kernel__("core.gt", v0, c1)
        yield v2, [i0, i1]
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_big_team
    # TODO: Implement materialization for big_team
    __materialize_from_each(:big_team)
  end

  def _each_company_total
    # TODO: Implement streaming method for company_total
    acc_2 = 0
      acc_1 = 0
      acc_2 += v1
        v0 = a1["headcount"]
        acc_1 += v0
    v2 = acc_2
      v1 = acc_1
    yield v2, []
  end

  def _eval_company_total
    # TODO: Implement materialization for company_total
    _each_company_total { |value, _| return value }
  end

  def _each_dept_total
    # TODO: Implement streaming method for dept_total
      acc_1 = 0
    arr0 = @input["depts"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      yield v1, [i0]
        v0 = a1["headcount"]
        acc_1 += v0
      i0 += 1
    end
      v1 = acc_1
  end

  def _eval_dept_total
    # TODO: Implement materialization for dept_total
    __materialize_from_each(:dept_total)
  end

  def _each_dept_total_masked
    # TODO: Implement streaming method for dept_total_masked
      acc_4 = 0
    arr0 = @input["depts"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
    c2 = 0
    c2 = 0
      yield v4, [i0, i1]
        v0 = self[:big_team][i0][i1]
        v1 = a1["headcount"]
        v3 = (v0 ? v1 : c2)
        acc_4 += v3
      i0 += 1
    end
      v4 = acc_4
  end

  def _eval_dept_total_masked
    # TODO: Implement materialization for dept_total_masked
    __materialize_from_each(:dept_total_masked)
  end

  def [](name)
    case name
    when :big_team then _eval_big_team
    when :company_total then _eval_company_total
    when :dept_total then _eval_dept_total
    when :dept_total_masked then _eval_dept_total_masked
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
    return (->(a,b) { a + b }).call(*args) if id == "agg.sum"
    return (->(a, b) { a > b }).call(*args) if id == "core.gt"
    raise KeyError, "Unknown kernel: #{id}"
  end
end