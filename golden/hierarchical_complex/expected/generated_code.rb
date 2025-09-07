module SchemaModule
  # Generated code with pack hash: ea2112c3b287545b57f6ae67e101522b86580958c0b422fd0c53171bc49f6868:358bbed3e9c32bc69b062410e9e344b627ef20e022740ad6c9c6a453523e3cce:cb3e821faa6ab47a1ff5b212032056df528d003cbf2459ab357e74bd457655b6

  def _each_high_performer
    op1 = 4.5
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
          arr3 = a2["employees"]
          arr3.each_with_index do |a3, i3|
            op0 = a3["rating"]
            op2 = __call_kernel__("core.gte", op0, 4.5)
            yield op2, [i0, i1, i2, i3]
          end
        end
      end
    end
  end

  def _eval_high_performer
    __materialize_from_each(:high_performer)
  end

  def _each_senior_level
    op4 = "senior"
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
          arr3 = a2["employees"]
          arr3.each_with_index do |a3, i3|
            op3 = a3["level"]
            op5 = __call_kernel__("core.eq", op3, "senior")
            yield op5, [i0, i1, i2, i3]
          end
        end
      end
    end
  end

  def _eval_senior_level
    __materialize_from_each(:senior_level)
  end

  def _each_top_team
    op7 = 0.9
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
          op6 = a2["performance_score"]
          op8 = __call_kernel__("core.gte", op6, 0.9)
          yield op8, [i0, i1, i2]
        end
      end
    end
  end

  def _eval_top_team
    __materialize_from_each(:top_team)
  end

  def _each_employee_bonus
    op15 = 0.3
    op20 = 0.2
    op22 = 0.05
    arr0 = @input["regions"]
    arr0.each_with_index do |a0, i0|
      arr1 = a0["offices"]
      arr1.each_with_index do |a1, i1|
        arr2 = a1["teams"]
        arr2.each_with_index do |a2, i2|
          arr3 = a2["employees"]
          arr3.each_with_index do |a3, i3|
            op11 = self[:top_team][i0][i1][i2]
            op18 = self[:top_team][i0][i1][i2]
            op9 = self[:high_performer][i0][i1][i2][i3]
            op10 = self[:senior_level][i0][i1][i2][i3]
            op12 = __call_kernel__("core.and", op10, op11)
            op13 = __call_kernel__("core.and", op9, op12)
            op14 = a3["salary"]
            op16 = __call_kernel__("core.mul", op14, 0.3)
            op17 = self[:high_performer][i0][i1][i2][i3]
            op19 = __call_kernel__("core.and", op17, op18)
            op21 = __call_kernel__("core.mul", op14, 0.2)
            op23 = __call_kernel__("core.mul", op14, 0.05)
            op24 = (op19 ? op21 : op23)
            op25 = (op13 ? op16 : op24)
            yield op25, [i0, i1, i2, i3]
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