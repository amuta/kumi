module SchemaModule
  # Generated code with pack hash: 58f3a405781061c82f6e1656b83a759c7118b6b89d41c231d22f18aa1e7e8af4:6ec2da57b6781ac2d994432609b60356af2bfbd52c362b2f8983c8723ed9d3e3:ceadd786494ca24eba7e856ae169b3f9a404987ad08ce9ea0e41bc8ed0400239

  def _each_double
    c1 = 2
    v0 = @input["x"]["y"]["z"]
    v2 = __call_kernel__("core.mul", v0, c1)
    yield v2, []
  end

  def _eval_double
    _each_double { |value, _| return value }
  end

  def [](name)
    case name
    when :double then _eval_double
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
    return (->(a, b) { a * b }).call(*args) if id == "core.mul"
    raise KeyError, "Unknown kernel: #{id}"
  end
end