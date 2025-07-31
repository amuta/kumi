# frozen_string_literal: true

require_relative "grammar"
require_relative "transform"
require_relative "../error_reporting"

module Kumi
  module TextParser
    # Parslet-based parser with proper arithmetic operator precedence
    class ParsletParser
      include Kumi::ErrorReporting
      
      def initialize
        @grammar = Grammar.new
        @transform = Transform.new
      end
      
      def parse(text_dsl, source_file: "<parslet_parser>")
        begin
          # Parse with Parslet grammar
          parse_tree = @grammar.parse(text_dsl)
          
          # Transform to AST
          ast = @transform.apply(parse_tree)
          
          # Post-process to create final Root node if needed
          post_process(ast)
        rescue Parslet::ParseFailed => e
          raise_syntax_error(
            "Parse error: #{e.parse_failure_cause.ascii_tree}",
            location: create_location(source_file, 1, 1)
          )
        end
      end
      
      private
      
      def post_process(ast)
        # If it's already a Root node, return it
        return ast if ast.is_a?(Syntax::Root)
        
        # If it's a hash with input and declarations, convert it
        if ast.is_a?(Hash) && ast[:input] && ast[:declarations]
          input_decls = ast[:input][:declarations] || []
          input_decls = [input_decls] unless input_decls.is_a?(Array)
          
          other_decls = ast[:declarations] || []
          other_decls = [other_decls] unless other_decls.is_a?(Array)
          
          # Convert remaining hash values to proper nodes
          values = []
          traits = []
          
          other_decls.each do |decl|
            if decl.is_a?(Hash) && decl[:name] && decl[:expr]
              expr = process_expression(decl[:expr])
              values << Syntax::ValueDeclaration.new(decl[:name], expr, loc: create_location("<parslet>", 1, 1))
            elsif decl.is_a?(Syntax::ValueDeclaration)
              # Need to process the expression if it's still a hash
              if decl.expression.is_a?(Hash)
                processed_expr = process_expression(decl.expression)
                values << Syntax::ValueDeclaration.new(decl.name, processed_expr, loc: decl.loc)
              else
                values << decl
              end
            elsif decl.is_a?(Syntax::TraitDeclaration)
              traits << decl
            end
          end
          
          Syntax::Root.new(input_decls, values, traits, loc: create_location("<parslet>", 1, 1))
        else
          ast
        end
      end
      
      def process_expression(expr)
        # If it's already a proper AST node, return it
        return expr unless expr.is_a?(Hash)
        
        # Handle nested expression structures
        if expr[:left] && expr[:ops]
          left_expr = process_expression(expr[:left])
          ops = expr[:ops] || []
          ops = [ops] unless ops.is_a?(Array)
          
          result = ops.inject(left_expr) do |left, op|
            if op.is_a?(Hash) && op[:op] && op[:right]
              op_name = op[:op].keys.first
              right_expr = process_expression(op[:right])
              Syntax::CallExpression.new(op_name, [left, right_expr], loc: create_location("<parslet>", 1, 1))
            else
              left
            end
          end
          
          # Handle comparison
          if expr[:comp] && expr[:comp][:op] && expr[:comp][:right]
            comp = expr[:comp]
            op_name = comp[:op].keys.first
            right_expr = process_expression(comp[:right])
            Syntax::CallExpression.new(op_name, [result, right_expr], loc: create_location("<parslet>", 1, 1))
          else
            result
          end
        else
          expr
        end
      end
      
      def create_location(file, line, column)
        Syntax::Location.new(file: file, line: line, column: column)
      end
    end
  end
end