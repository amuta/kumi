# frozen_string_literal: true

module Kumi
  module Support
    class SExpressionPrinter
      def initialize(indent: 0)
        @indent = indent
      end

      def visit(node)
        return node.inspect unless node.respond_to?(:class)
        
        case node
        when nil then "nil"
        when Array then visit_array(node)
        when Kumi::Syntax::Root then visit_root(node)
        when Kumi::Syntax::ValueDeclaration then visit_value_declaration(node)
        when Kumi::Syntax::TraitDeclaration then visit_trait_declaration(node)
        when Kumi::Syntax::InputDeclaration then visit_input_declaration(node)
        when Kumi::Syntax::CallExpression then visit_call_expression(node)
        when Kumi::Syntax::ArrayExpression then visit_array_expression(node)
        when Kumi::Syntax::CascadeExpression then visit_cascade_expression(node)
        when Kumi::Syntax::CaseExpression then visit_case_expression(node)
        when Kumi::Syntax::InputReference then visit_input_reference(node)
        when Kumi::Syntax::InputElementReference then visit_input_element_reference(node)
        when Kumi::Syntax::DeclarationReference then visit_declaration_reference(node)
        when Kumi::Syntax::Literal then visit_literal(node)
        when Kumi::Syntax::HashExpression then visit_hash_expression(node)
        else visit_generic(node)
        end
      end

      def self.print(node, indent: 0)
        new(indent: indent).visit(node)
      end

      private

      def visit_array(node)
        return "[]" if node.empty?
        
        elements = node.map { |child| child_printer.visit(child) }
        "[\n#{indent_str(2)}#{elements.join("\n#{indent_str(2)}")}\n#{indent_str}]"
      end

      def visit_root(node)
        fields = %i[inputs attributes traits].map do |field|
          value = node.public_send(field)
          "#{field}: #{child_printer.visit(value)}"
        end.join("\n#{indent_str(2)}")
        
        "(Root\n#{indent_str(2)}#{fields}\n#{indent_str})"
      end

      def visit_value_declaration(node)
        "(ValueDeclaration :#{node.name}\n#{child_indent}#{child_printer.visit(node.expression)}\n#{indent_str})"
      end

      def visit_trait_declaration(node)
        "(TraitDeclaration :#{node.name}\n#{child_indent}#{child_printer.visit(node.expression)}\n#{indent_str})"
      end

      def visit_input_declaration(node)
        fields = [":#{node.name}"]
        fields << ":#{node.type}" if node.respond_to?(:type) && node.type
        fields << "domain: #{node.domain.inspect}" if node.respond_to?(:domain) && node.domain
        fields << "access_mode: #{node.access_mode.inspect}" if node.respond_to?(:access_mode) && node.access_mode
        
        if node.respond_to?(:children) && !node.children.empty?
          children_str = child_printer.visit(node.children)
          "(InputDeclaration #{fields.join(' ')}\n#{child_indent}#{children_str}\n#{indent_str})"
        else
          "(InputDeclaration #{fields.join(' ')})"
        end
      end

      def visit_call_expression(node)
        return "(CallExpression :#{node.fn_name})" if node.args.empty?
        
        args = node.args.map { |arg| child_printer.visit(arg) }
        "(CallExpression :#{node.fn_name}\n#{indent_str(2)}#{args.join("\n#{indent_str(2)}")}\n#{indent_str})"
      end

      def visit_array_expression(node)
        return "(ArrayExpression)" if node.elements.empty?
        
        elements = node.elements.map { |elem| child_printer.visit(elem) }
        "(ArrayExpression\n#{indent_str(2)}#{elements.join("\n#{indent_str(2)}")}\n#{indent_str})"
      end

      def visit_cascade_expression(node)
        cases = node.cases.map do |case_expr|
          "(#{visit(case_expr.condition)} #{visit(case_expr.result)})"
        end.join("\n#{indent_str(2)}")
        
        "(CascadeExpression\n#{indent_str(2)}#{cases}\n#{indent_str})"
      end

      def visit_case_expression(node)
        "(CaseExpression #{visit(node.condition)} #{visit(node.result)})"
      end

      def visit_input_reference(node)
        "(InputReference :#{node.name})"
      end

      def visit_input_element_reference(node)
        "(InputElementReference #{node.path.map(&:to_s).join('.')})"
      end

      def visit_declaration_reference(node)
        "(DeclarationReference :#{node.name})"
      end

      def visit_literal(node)
        "(Literal #{node.value.inspect})"
      end

      def visit_hash_expression(node)
        return "(HashExpression)" if node.pairs.empty?
        
        pairs = node.pairs.map do |pair|
          "(#{visit(pair.key)} #{visit(pair.value)})"
        end.join("\n#{indent_str(2)}")
        
        "(HashExpression\n#{indent_str(2)}#{pairs}\n#{indent_str})"
      end

      def visit_generic(node)
        class_name = node.class.name&.split('::')&.last || node.class.to_s
        
        if node.respond_to?(:children) && !node.children.empty?
          children = node.children.map { |child| child_printer.visit(child) }
          "(#{class_name}\n#{indent_str(2)}#{children.join("\n#{indent_str(2)}")}\n#{indent_str})"
        elsif node.respond_to?(:members)
          fields = node.members.reject { |m| m == :loc }.map do |member|
            value = node[member]
            "#{member}: #{child_printer.visit(value)}"
          end
          
          return "(#{class_name})" if fields.empty?
          
          "(#{class_name}\n#{indent_str(2)}#{fields.join("\n#{indent_str(2)}")}\n#{indent_str})"
        else
          "(#{class_name} #{node.inspect})"
        end
      end

      def child_printer
        @child_printer ||= self.class.new(indent: @indent + 2)
      end

      def indent_str(extra = 0)
        ' ' * (@indent + extra)
      end

      def child_indent
        indent_str(2)
      end
    end
  end
end