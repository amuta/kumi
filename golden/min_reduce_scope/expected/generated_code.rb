module SchemaModule
  # Generated code with pack hash: afe16a37162e4b64766c1e62c9335166e1ff9d711f3380ef32a06de5d4da1ae4:23781ff3829e35eb8ee89552414d3e9a68e95d4dacfe5edbe6752e04984e4e46:ff798621f7e88e6ce6be894738c2ab8c5f41eefa845dd338db08039804654799

  def _each_dept_total
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        acc_1 = 0
        v0 = a1["headcount"]
        acc_1 += v0
        v1 = acc_1
        yield v1, [i0]
      end
    end
  end

  def _eval_dept_total
    __materialize_from_each(:dept_total)
  end

  def _each_company_total
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      acc_2 = 0
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        acc_1 = 0
        v0 = a1["headcount"]
        acc_1 += v0
        v1 = acc_1
        acc_2 += v1
      end
      v2 = acc_2
      yield v2, []
    end
  end

  def _eval_company_total
    _each_company_total { |value, _| return value }
  end

  def _each_big_team
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      c1 = 10
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        v0 = a1["headcount"]
        v2 = __call_kernel__("core.gt", v0, v1)
        yield v2, [i0, i1]
      end
    end
  end

  def _eval_big_team
    __materialize_from_each(:big_team)
  end

  def _each_dept_total_masked
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      c2 = 0
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        acc_4 = 0
        v1 = a1["headcount"]
        cbig_team_1 = 10
        v0_big_team = a1["headcount"]
        v0 = __call_kernel__("core.gt", v0_big_team, cbig_team_1)
        v3 = (v0 ? v1 : v2)
        acc_4 += v3
        v4 = acc_4
        yield v4, [i0]
      end
    end
  end

  def _eval_dept_total_masked
    __materialize_from_each(:dept_total_masked)
  end

  def [](name)
    case name
    when :dept_total then _eval_dept_total
    when :company_total then _eval_company_total
    when :big_team then _eval_big_team
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