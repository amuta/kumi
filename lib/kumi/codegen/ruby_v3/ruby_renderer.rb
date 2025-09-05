# frozen_string_literal: true

# Deterministic renderer that prints ops in the given order. No regrouping.
# It only needs each op's :k, :depth, and any op-specific fields.

module Kumi
  module Codegen
    module RubyV3
      module RubyRenderer
        module_function

        def render(program:, module_name:, pack_hash:, kernels_table:)
          lines = []
          lines << "module #{module_name}"
          lines << "  # Generated code with pack hash: #{pack_hash}"
          lines << ""

          program.each do |fn|
            lines << "  def _each_#{fn.name}"
            render_ordered_ops(lines, fn.ops)
            lines << "  end"
            lines << ""

            lines << "  def _eval_#{fn.name}"
            lines << if fn.rank.zero?
                       "    _each_#{fn.name} { |value, _| return value }"
                     else
                       "    __materialize_from_each(:#{fn.name})"
                     end
            lines << "  end"
            lines << ""
          end

          lines << "  def [](name)"
          lines << "    case name"
          program.each { |fn| lines << "    when :#{fn.name} then _eval_#{fn.name}" }
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

        def render_ordered_ops(lines, ops)
          indent = 2
          loops_open = 0

          ops.each do |op|
            case op[:k]
            when :OpenLoop
              src = op[:depth].zero? ? "@input" : "a#{op[:depth] - 1}"
              lines << if op[:key]
                         "#{'  ' * indent}arr#{op[:depth]} = #{src}[#{op[:key].inspect}]"
                       else
                         "#{'  ' * indent}arr#{op[:depth]} = #{src}"
                       end
              lines << "#{'  ' * indent}arr#{op[:depth]}.each_with_index do |a#{op[:depth]}, i#{op[:depth]}|"
              indent += 1
              loops_open += 1

            when :AccReset
              lines << "#{'  ' * indent}#{op[:name]} = #{op[:init]}"

            when :Emit
              lines << "#{'  ' * indent}#{op[:code]}"

            when :AccAdd
              lines << "#{'  ' * indent}#{op[:name]} += #{op[:expr]}"

            when :Yield
              idxs = op[:indices].map.with_index { |_, i| "i#{i}" }.join(", ")
              lines << "#{'  ' * indent}yield #{op[:expr]}, [#{idxs}]"

            when :CloseLoop
              indent -= 1
              lines << "#{'  ' * indent}end"
              loops_open -= 1
            end
          end

          raise "unbalanced loops" unless loops_open.zero?
        end
      end
    end
  end
end
