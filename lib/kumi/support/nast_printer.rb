# frozen_string_literal: true

module Kumi
  module Support
    class NASTPrinter
      def self.print(nir_module)
        new.print(nir_module)
      end

      def initialize(indent: 0)
        @indent = indent
      end

      def print(nir_module)
        return "nil" unless nir_module

        lines = []
        lines << "(NAST"
        
        nir_module.decls.each do |name, decl|
          lines << indent("(#{decl.kind.upcase} #{name}")
          lines << indent(print_node(decl.body), 2)
          lines << indent(")")
        end
        
        lines << ")"
        lines.join("\n")
      end

      private

      def print_node(node, depth = 1)
        case node
        when Kumi::Core::NAST::Const
          "(Const #{node.value.inspect})"
          
        when Kumi::Core::NAST::InputRef
          "(InputRef #{node.path.inspect})"
          
        when Kumi::Core::NAST::Ref
          "(Ref #{node.name})"
          
        when Kumi::Core::NAST::Call
          if node.args.empty?
            "(Call #{node.fn.inspect})"
          else
            lines = ["(Call #{node.fn.inspect}"]
            node.args.each do |arg|
              lines << indent(print_node(arg, depth + 1), depth + 1)
            end
            lines << indent(")", depth)
            lines.join("\n")
          end
          
        else
          node.inspect
        end
      end

      def indent(text, level = 1)
        "  " * level + text
      end
    end
  end
end