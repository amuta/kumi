# Zeitwerk: Kumi::Codegen::RubyV3::RubyRenderer

module Kumi::Codegen::RubyV3::RubyRenderer
  module_function
  
  def render(program:, module_name:, pack_hash:, kernels_table:)
    lines = []
    lines << "module #{module_name}"
    lines << "  # Generated code with pack hash: #{pack_hash}"
    lines << ""
    
    program.each do |fn|
      # Streaming method
      lines << "  def _each_#{fn.name}"
      lines << "    # TODO: Implement streaming method for #{fn.name}"
      
      
      fn.ops.each do |op|
        indent = "  " * (op[:depth] + 2)
        case op[:k]
        when :Emit
          lines << "#{indent}#{op[:code]}"
        when :OpenLoop
          via_key = op[:via_path].last
          if op[:depth] == 0
            lines << "#{indent}arr#{op[:depth]} = @input[#{via_key.inspect}]"
            lines << "#{indent}i#{op[:depth]} = 0"
            lines << "#{indent}a#{op[:depth]} = nil"
            lines << "#{indent}while i#{op[:depth]} < arr#{op[:depth]}.length"
            lines << "#{indent}  a#{op[:depth]} = arr#{op[:depth]}[i#{op[:depth]}]"
          else
            lines << "#{indent}arr#{op[:depth]} = a#{op[:depth] - 1}[#{via_key.inspect}]"
            lines << "#{indent}i#{op[:depth]} = 0"
            lines << "#{indent}a#{op[:depth]} = nil"
            lines << "#{indent}while i#{op[:depth]} < arr#{op[:depth]}.length"
            lines << "#{indent}  a#{op[:depth]} = arr#{op[:depth]}[i#{op[:depth]}]"
          end
        when :CloseLoop
          lines << "#{indent}  i#{op[:depth]} += 1"
          lines << "#{indent}end"
        when :AccReset
          lines << "#{indent}#{op[:name]} = #{op[:init]}"
        when :AccAdd
          lines << "#{indent}#{op[:name]} += #{op[:expr]}"
        when :Yield
          indices = op[:indices].map.with_index { |_, i| "i#{i}" }.join(", ")
          lines << "#{indent}yield #{op[:expr]}, [#{indices}]"
        end
      end
      
      lines << "  end"
      lines << ""
      
      # Materialization method
      lines << "  def _eval_#{fn.name}"
      lines << "    # TODO: Implement materialization for #{fn.name}"
      if fn.rank == 0
        lines << "    _each_#{fn.name} { |value, _| return value }"
      else
        lines << "    __materialize_from_each(:#{fn.name})"
      end
      lines << "  end"
      lines << ""
    end
    
    # Helper methods
    lines << "  def [](name)"
    lines << "    case name"
    program.each do |fn|
      lines << "    when :#{fn.name} then _eval_#{fn.name}"
    end
    lines << "    else raise KeyError, \"Unknown declaration: \#{name}\""
    lines << "    end"
    lines << "  end"
    lines << ""
    
    lines << "  def self.from(input_data)"
    lines << "    instance = Object.new"
    lines << "    instance.extend(self)"
    lines << "    instance.instance_variable_set(:@input, input_data)"
    lines << "    instance"
    lines << "  end"
    lines << ""
    
    lines << "  private"
    lines << ""
    lines << "  def __materialize_from_each(name)"
    lines << "    # TODO: Implement streaming to nested array conversion"
    lines << "    result = []"
    lines << "    send(\"_each_\#{name}\") do |value, indices|"
    lines << "      __nest_value(result, indices, value)"
    lines << "    end"
    lines << "    result"
    lines << "  end"
    lines << ""
    lines << "  def __nest_value(result, indices, value)"
    lines << "    current = result"
    lines << "    indices[0...-1].each do |idx|"
    lines << "      current[idx] ||= []"
    lines << "      current = current[idx]"
    lines << "    end"
    lines << "    current[indices.last] = value if indices.any?"
    lines << "  end"
    lines << ""
    lines << "  def __call_kernel__(id, *args)"
    lines << "    # TODO: Implement kernel dispatch"
    kernels_table.each do |kernel_id, impl|
      lines << "    return (#{impl}).call(*args) if id == #{kernel_id.inspect}"
    end
    lines << "    raise KeyError, \"Unknown kernel: \#{id}\""
    lines << "  end"
    lines << "end"
    
    lines.join("\n")
  end
end