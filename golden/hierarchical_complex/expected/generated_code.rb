module SchemaModule
  # Generated code with pack hash: ea2112c3b287545b57f6ae67e101522b86580958c0b422fd0c53171bc49f6868:70c186ead35e542951237068fc4cbd7b78bc11aec7265e0aa613d7271567747b:144f411868b975a04a236a53fc6588972b19a3410d20b038ac36594a9c477df3

  def _each_high_performer
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
    c1 = 4.5
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
          arr3 = a2["employees"]
          arr3.each_with_index do |a3, i3|
            v0 = a3["rating"]
            v2 = __call_kernel__("core.gte", v0, c1)
            yield v2, [i0, i1, i2, i3]
          end
        end
      end
    end
  end

  def _eval_high_performer
    __materialize_from_each(:high_performer)
  end

  def _each_senior_level
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
    c1 = "senior"
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
          arr3 = a2["employees"]
          arr3.each_with_index do |a3, i3|
            v0 = a3["level"]
            v2 = __call_kernel__("core.eq", v0, c1)
            yield v2, [i0, i1, i2, i3]
          end
        end
      end
    end
  end

  def _eval_senior_level
    __materialize_from_each(:senior_level)
  end

  def _each_top_team
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
    c1 = 0.9
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
          v0 = a2["performance_score"]
          v2 = __call_kernel__("core.gte", v0, c1)
          yield v2, [i0, i1, i2]
        end
      end
    end
  end

  def _eval_top_team
    __materialize_from_each(:top_team)
  end

  def _each_employee_bonus
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
    c6 = 0.3
    c11 = 0.2
    c13 = 0.05
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
        ctop_team_1 = 0.9
        v0_top_team = a2["performance_score"]
        v2 = __call_kernel__("core.gte", v0_top_team, ctop_team_1)
          arr3 = a2["employees"]
          arr3.each_with_index do |a3, i3|
          chigh_performer_1 = 4.5
          v0_high_performer = a3["rating"]
          v0 = __call_kernel__("core.gte", v0_high_performer, chigh_performer_1)
          csenior_level_1 = "senior"
          v0_senior_level = a3["level"]
          v1 = __call_kernel__("core.eq", v0_senior_level, csenior_level_1)
            v3 = __call_kernel__("core.and", csenior_level_1, v1)
            v4 = __call_kernel__("core.and", v0_senior_level, v3)
            v5 = a3["salary"]
            v7 = __call_kernel__("core.mul", v5, c6)
            v10 = __call_kernel__("core.and", v0_senior_level, v1)
            v12 = __call_kernel__("core.mul", v5, c11)
            v14 = __call_kernel__("core.mul", v5, c13)
            v15 = (v10 ? v12 : v14)
            v16 = (v4 ? v7 : v15)
            yield v16, [i0, i1, i2, i3]
          end
        end
      end
    end
  end

  def _eval_employee_bonus
    __materialize_from_each(:employee_bonus)
  end

  def [](name)
    case name
    when :high_performer then _eval_high_performer
    when :senior_level then _eval_senior_level
    when :top_team then _eval_top_team
    when :employee_bonus then _eval_employee_bonus
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
    return (->(a, b) { a >= b }).call(*args) if id == "core.gte"
    return (->(a, b) { a == b }).call(*args) if id == "core.eq"
    return (->(a, b) { a && b }).call(*args) if id == "core.and"
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    raise KeyError, "Unknown kernel: #{id}"
  end
end