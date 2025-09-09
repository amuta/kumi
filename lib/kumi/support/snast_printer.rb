# frozen_string_literal: true

module Kumi
  module Support
    class SNASTPrinter
      NAST = Kumi::Core::NAST

      def self.print(snast_module, verbosity: :default)
        new(verbosity: verbosity).print(snast_module)
      end

      def initialize(verbosity: :default)
        @verbosity = verbosity
      end

      def print(snast_module)
        return "nil" unless snast_module

        output = ["(SNAST"]
        snast_module.decls.each do |_, decl|
          output << format_node(decl, 1)
        end
        output << ")"
        output.join("\n")
      end

      private

      def format_node(node, indent_level)
        case @verbosity
        when :full
          indent = "  " * indent_level
          "#{indent}#{node.pretty_inspect.gsub("\n", "\n#{indent}")}"
        else
          format_concise(node, indent_level)
        end
      end

      def format_concise(node, indent_level)
        indent = "  " * indent_level

        case node
        when NAST::Declaration
          stamp_str = format_stamp(node.meta[:stamp])
          kind = node.meta.dig(:stamp, :dtype) == :boolean ? "TRAIT" : "VALUE"
          header = "(#{kind} #{node.name}"
          body = format_concise(node.body, indent_level + 1)
          "#{indent}#{header}\n#{body}\n#{indent}) #{stamp_str}"

        when NAST::Call
          stamp_str = format_stamp(node.meta[:stamp])
          header = "(Call :#{node.fn}"
          args = node.args.map { |arg| format_concise(arg, indent_level + 1) }.join("\n")
          "#{indent}#{header}\n#{args}\n#{indent}) #{stamp_str}"

        when NAST::Select
          stamp_str = format_stamp(node.meta[:stamp])
          header = "(Select"
          cond  = format_concise(node.cond,     indent_level + 1)
          tbranch = format_concise(node.on_true,  indent_level + 1)
          fbranch = format_concise(node.on_false, indent_level + 1)
          "#{indent}#{header}\n#{cond}\n#{tbranch}\n#{fbranch}\n#{indent}) #{stamp_str}"

        when NAST::Reduce
          stamp_str = format_stamp(node.meta[:stamp])
          over = "[#{Array(node.over).map(&:to_s).join(', ')}]"
          header = "(Reduce :#{node.op_id} over #{over}"
          arg = format_concise(node.arg, indent_level + 1)
          "#{indent}#{header}\n#{arg}\n#{indent}) #{stamp_str}"

        when NAST::Const
          stamp_str = format_stamp(node.meta[:stamp])
          "#{indent}(Const #{node.value.inspect}) #{stamp_str}"

        when NAST::InputRef
          stamp_str = format_stamp(node.meta[:stamp])
          key_chain_str = " key_chain=[#{node.key_chain.join(", ")}]"
          "#{indent}(InputRef #{node.path_fqn}#{key_chain_str}) #{stamp_str}"

        when NAST::Ref
          stamp_str = format_stamp(node.meta[:stamp])
          "#{indent}(Ref #{node.name}) #{stamp_str}"

        when NAST::Tuple
          stamp_str = format_stamp(node.meta[:stamp])
          header = "(Tuple"
          args = node.args.map { |arg| format_concise(arg, indent_level + 1) }.join("\n")
          "#{indent}#{header}\n#{args}\n#{indent}) #{stamp_str}"

        else
          "#{indent}(UnknownNode: #{node.class})"
        end
      end

      def format_stamp(stamp)
        return "" unless stamp
        axes = Array(stamp[:axes]).map(&:to_s).join(", ")
        ":: [#{axes}] -> #{stamp[:dtype]}"
      end
    end
  end
end
