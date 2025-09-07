module SchemaModule
  # Generated code with pack hash: afe16a37162e4b64766c1e62c9335166e1ff9d711f3380ef32a06de5d4da1ae4:02d5f9ffea6d56c4575867638cb059ae97a5f9bcbbd590a5ede0a1cba1de59f2:5c5fc55e99e9d032f2b6aa2724bfb55b8e404b9268fd1e9c12abf8fd1a00e104

  def _each_dept_total
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      acc_1 = 0
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        op0 = a1["headcount"]
        acc_1 = __call_kernel__("agg.sum", acc_1, op0)
      end
      op1 = acc_1
      yield op1, [i0]
    end
  end

  def _eval_dept_total
    __materialize_from_each(:dept_total)
  end

  def _each_company_total
    acc_4 = 0
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      acc_3 = 0
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        op2 = a1["headcount"]
        acc_3 = __call_kernel__("agg.sum", acc_3, op2)
      end
      op3 = acc_3
      acc_4 = __call_kernel__("agg.sum", acc_4, op3)
    end
    op4 = acc_4
    yield op4, []
  end

  def _eval_company_total
    _each_company_total { |value, _| return value }
  end

  def _each_big_team
    op6 = 10
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        op5 = a1["headcount"]
        op7 = __call_kernel__("core.gt", op5, 10)
        yield op7, [i0, i1]
      end
    end
  end

  def _eval_big_team
    __materialize_from_each(:big_team)
  end

  def _each_dept_total_masked
    op10 = 0
    arr0 = @input["depts"]
    arr0.each_with_index do |a0, i0|
      acc_12 = 0
      arr1 = a0["teams"]
      arr1.each_with_index do |a1, i1|
        op8 = self[:big_team][i0][i1]
        op9 = a1["headcount"]
        op11 = (op8 ? op9 : 0)
        acc_12 = __call_kernel__("agg.sum", acc_12, op11)
      end
      op12 = acc_12
      yield op12, [i0]
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