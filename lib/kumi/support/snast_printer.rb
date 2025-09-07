# frozen_string_literal: true

module Kumi
  module Support
    class SNASTPrinter
      def self.print(snast_module, verbosity: :default)
        new(verbosity: verbosity).print(snast_module)
      end

      def initialize(verbosity: :default)
        @verbosity = verbosity
      end

      def print(snast_module)
        return "nil" unless snast_module

        output = ["(SNAST"]
        snast_module.decls.each do |name, decl|
          output << format_node(decl, 1)
        end
        output << ")"
        output.join("\n")
      end

      private

      def format_node(node, indent_level)
        indent = "  " * indent_level
        case @verbosity
        when :full
          "#{indent}#{node.pretty_inspect.gsub("\n", "\n#{indent}")}"
        else
          format_concise(node, indent_level)
        end
      end

      def format_concise(node, indent_level)
        indent = "  " * indent_level
        
        case node
        when Kumi::Core::NAST::Declaration
          stamp_str = format_stamp(node.meta[:stamp])
          kind = node.meta.dig(:stamp, :dtype) == :boolean ? "TRAIT" : "VALUE"
          header = "(#{kind} #{node.name}"
          body = format_concise(node.body, indent_level + 1)
          "#{indent}#{header}\n#{body}\n#{indent}) #{stamp_str}"
        when Kumi::Core::NAST::Call
          stamp_str = format_stamp(node.meta[:stamp])
          header = "(Call :#{node.fn}"
          args = node.args.map { |arg| format_concise(arg, indent_level + 1) }.join("\n")
          "#{indent}#{header}\n#{args}\n#{indent}) #{stamp_str}"
        when Kumi::Core::NAST::Const
          stamp_str = format_stamp(node.meta[:stamp])
          "#{indent}(Const #{node.value.inspect}) #{stamp_str}"
        when Kumi::Core::NAST::InputRef
          stamp_str = format_stamp(node.meta[:stamp])
          "#{indent}(InputRef [:#{node.path.join(', :')}]) #{stamp_str}"
        when Kumi::Core::NAST::Ref
          stamp_str = format_stamp(node.meta[:stamp])
          "#{indent}(Ref #{node.name}) #{stamp_str}"
        when Kumi::Core::NAST::Tuple
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