# frozen_string_literal: true

module Kumi
  module Support
    class SNASTPrinter
      def self.print(snast_module)
        new.print(snast_module)
      end

      def initialize(indent: 0)
        @indent = indent
      end

      def print(snast_module)
        return "nil" unless snast_module

        lines = []
        lines << "(SNAST"
        
        snast_module.decls.each do |name, decl|
          lines << indent("(#{decl.kind.upcase} #{name}")
          lines << print_declaration_meta(decl, 2)
          lines << indent(print_node(decl.body), 2)
          lines << indent(")")
        end
        
        lines << ")"
        lines.join("\n")
      end

      private

      def print_declaration_meta(decl, depth)
        meta = decl.meta
        stamp = meta[:stamp]
        
        lines = []
        lines << indent("meta: {", depth)
        lines << indent("stamp: {axes_tokens: #{stamp[:axes_tokens].inspect}, dtype: #{stamp[:dtype]}}", depth + 1)
        lines << indent("value_id: #{meta[:value_id].inspect}", depth + 1)
        lines << indent("topo_index: #{meta[:topo_index]}", depth + 1)
        lines << indent("target_name: #{meta[:target_name].inspect}", depth + 1)
        lines << indent("}", depth)
        
        lines.join("\n")
      end

      def print_node(node, depth = 1)
        case node
        when Kumi::Core::NAST::Const
          lines = ["(Const #{node.value.inspect}"]
          lines << print_node_meta(node, depth + 1)
          lines << indent(")", depth)
          lines.join("\n")
          
        when Kumi::Core::NAST::InputRef
          lines = ["(InputRef #{node.path.inspect}"]
          lines << print_node_meta(node, depth + 1)
          lines << indent(")", depth)
          lines.join("\n")
          
        when Kumi::Core::NAST::Ref
          lines = ["(Ref #{node.name}"]
          lines << print_node_meta(node, depth + 1)
          lines << indent(")", depth)
          lines.join("\n")
          
        when Kumi::Core::NAST::Call
          lines = ["(Call #{node.fn.inspect}"]
          lines << print_call_meta(node, depth + 1)
          
          unless node.args.empty?
            lines << indent("args:", depth + 1)
            node.args.each do |arg|
              lines << indent(print_node(arg, depth + 2), depth + 2)
            end
          end
          
          lines << indent(")", depth)
          lines.join("\n")
          
        else
          node.inspect
        end
      end

      def print_node_meta(node, depth)
        meta = node.meta
        stamp = meta[:stamp]
        
        lines = []
        lines << indent("meta: {", depth)
        lines << indent("stamp: {axes_tokens: #{stamp[:axes_tokens].inspect}, dtype: #{stamp[:dtype]}}", depth + 1)
        lines << indent("value_id: #{meta[:value_id].inspect}", depth + 1)  
        lines << indent("topo_index: #{meta[:topo_index]}", depth + 1)
        
        # Add specific metadata for Refs
        if meta[:referenced_name]
          lines << indent("referenced_name: #{meta[:referenced_name].inspect}", depth + 1)
        end
        
        lines << indent("}", depth)
        lines.join("\n")
      end

      def print_call_meta(call_node, depth)
        meta = call_node.meta
        stamp = meta[:stamp]
        plan = meta[:plan]
        
        lines = []
        lines << indent("meta: {", depth)
        lines << indent("stamp: {axes_tokens: #{stamp[:axes_tokens].inspect}, dtype: #{stamp[:dtype]}}", depth + 1)
        lines << indent("value_id: #{meta[:value_id].inspect}", depth + 1)
        lines << indent("topo_index: #{meta[:topo_index]}", depth + 1)
        
        # Print execution plan
        lines << indent("plan: {", depth + 1)
        lines << indent("kind: #{plan[:kind]}", depth + 2)
        
        case plan[:kind]
        when :elementwise
          lines << indent("target_axes_tokens: #{plan[:target_axes_tokens].inspect}", depth + 2)
          lines << indent("needs_expand_flags: #{plan[:needs_expand_flags].inspect}", depth + 2)
        when :reduce  
          lines << indent("last_axis_token: #{plan[:last_axis_token].inspect}", depth + 2)
        when :constructor
          lines << indent("arity: #{plan[:arity]}", depth + 2)
          lines << indent("target_axes_tokens: #{plan[:target_axes_tokens].inspect}", depth + 2)
          lines << indent("needs_expand_flags: #{plan[:needs_expand_flags].inspect}", depth + 2)
        end
        
        lines << indent("}", depth + 1)
        lines << indent("}", depth)
        
        lines.join("\n")
      end

      def indent(text, level = 1)
        "  " * level + text
      end
    end
  end
end