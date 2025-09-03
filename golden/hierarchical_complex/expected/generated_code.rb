module SchemaModule
  # Generated code with pack hash: ea2112c3b287545b57f6ae67e101522b86580958c0b422fd0c53171bc49f6868:0a34965cab469dd0d47da509e8dda32d6d385c5a97ca786d0ec12b3bb3416e1b:144f411868b975a04a236a53fc6588972b19a3410d20b038ac36594a9c477df3

  def _each_employee_bonus
    # TODO: Implement streaming method for employee_bonus
    arr0 = @input["regions"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["offices"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["teams"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
          arr3 = a2["employees"]
          i3 = 0
          a3 = nil
          while i3 < arr3.length
            a3 = arr3[i3]
    c6 = 0.3
    c11 = 0.2
    c13 = 0.05
    c6 = 0.3
    c11 = 0.2
    c13 = 0.05
          v2 = self[:top_team][i0][i1][i2]
            v0 = self[:high_performer][i0][i1][i2][i3]
            v1 = self[:senior_level][i0][i1][i2][i3]
            v3 = __call_kernel__("core.and", v1, v2)
            v4 = __call_kernel__("core.and", v0, v3)
            v5 = a3["salary"]
            v7 = __call_kernel__("core.mul", v5, c6)
            v10 = __call_kernel__("core.and", v0, v2)
            v12 = __call_kernel__("core.mul", v5, c11)
            v14 = __call_kernel__("core.mul", v5, c13)
            v15 = (v10 ? v12 : v14)
            v16 = (v4 ? v7 : v15)
            yield v16, [i0, i1, i2, i3]
            i3 += 1
          end
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_employee_bonus
    # TODO: Implement materialization for employee_bonus
    __materialize_from_each(:employee_bonus)
  end

  def _each_high_performer
    # TODO: Implement streaming method for high_performer
    arr0 = @input["regions"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["offices"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["teams"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
          arr3 = a2["employees"]
          i3 = 0
          a3 = nil
          while i3 < arr3.length
            a3 = arr3[i3]
    c1 = 4.5
    c1 = 4.5
            v0 = a3["rating"]
            v2 = __call_kernel__("core.gte", v0, c1)
            yield v2, [i0, i1, i2, i3]
            i3 += 1
          end
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_high_performer
    # TODO: Implement materialization for high_performer
    __materialize_from_each(:high_performer)
  end

  def _each_senior_level
    # TODO: Implement streaming method for senior_level
    arr0 = @input["regions"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["offices"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["teams"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
          arr3 = a2["employees"]
          i3 = 0
          a3 = nil
          while i3 < arr3.length
            a3 = arr3[i3]
    c1 = "senior"
    c1 = "senior"
            v0 = a3["level"]
            v2 = __call_kernel__("core.eq", v0, c1)
            yield v2, [i0, i1, i2, i3]
            i3 += 1
          end
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_senior_level
    # TODO: Implement materialization for senior_level
    __materialize_from_each(:senior_level)
  end

  def _each_top_team
    # TODO: Implement streaming method for top_team
    arr0 = @input["regions"]
    i0 = 0
    a0 = nil
    while i0 < arr0.length
      a0 = arr0[i0]
      arr1 = a0["offices"]
      i1 = 0
      a1 = nil
      while i1 < arr1.length
        a1 = arr1[i1]
        arr2 = a1["teams"]
        i2 = 0
        a2 = nil
        while i2 < arr2.length
          a2 = arr2[i2]
    c1 = 0.9
    c1 = 0.9
          v0 = a2["performance_score"]
          v2 = __call_kernel__("core.gte", v0, c1)
          yield v2, [i0, i1, i2]
          i2 += 1
        end
        i1 += 1
      end
      i0 += 1
    end
  end

  def _eval_top_team
    # TODO: Implement materialization for top_team
    __materialize_from_each(:top_team)
  end

  def [](name)
    case name
    when :employee_bonus then _eval_employee_bonus
    when :high_performer then _eval_high_performer
    when :senior_level then _eval_senior_level
    when :top_team then _eval_top_team
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
    return (->(a, b) { a >= b }).call(*args) if id == "core.gte"
    return (->(a, b) { a == b }).call(*args) if id == "core.eq"
    return (->(a, b) { a && b }).call(*args) if id == "core.and"
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    raise KeyError, "Unknown kernel: #{id}"
  end
end