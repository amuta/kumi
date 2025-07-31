# frozen_string_literal: true

require "parslet"
require_relative "../syntax/node"
require_relative "../syntax/root"
require_relative "../syntax/input_declaration"
require_relative "../syntax/value_declaration" 
require_relative "../syntax/trait_declaration"
require_relative "../syntax/call_expression"
require_relative "../syntax/input_reference"
require_relative "../syntax/declaration_reference"
require_relative "../syntax/literal"

module Kumi
  module TextParser
    class Transform < Parslet::Transform
      
      LOC = Syntax::Location.new(file: "<parslet_parser>", line: 1, column: 1)
      
      # Literals
      rule(integer: simple(:x)) { Syntax::Literal.new(x.to_i, loc: LOC) }
      rule(float: simple(:x)) { Syntax::Literal.new(x.to_f, loc: LOC) }
      rule(string: simple(:x)) { Syntax::Literal.new(x.to_s, loc: LOC) }
      rule(true: simple(:_)) { Syntax::Literal.new(true, loc: LOC) }
      rule(false: simple(:_)) { Syntax::Literal.new(false, loc: LOC) }
      
      # Symbols
      rule(symbol: simple(:name)) { name.to_sym }
      
      # Input and declaration references
      rule(input_ref: simple(:name)) { Syntax::InputReference.new(name.to_sym, loc: LOC) }
      rule(decl_ref: simple(:name)) { Syntax::DeclarationReference.new(name.to_sym, loc: LOC) }
      
      # Function calls
      rule(fn_name: simple(:name), args: sequence(:args)) do
        Syntax::CallExpression.new(name, args, loc: LOC)
      end
      
      rule(fn_name: simple(:name), args: []) do
        Syntax::CallExpression.new(name, [], loc: LOC)
      end
      
      # Arithmetic expressions with left-associativity
      rule(left: simple(:l), ops: sequence(:operations)) do
        operations.inject(l) do |left_expr, op|
          op_name = op[:op].keys.first
          Syntax::CallExpression.new(op_name, [left_expr, op[:right]], loc: LOC)
        end
      end
      
      rule(left: simple(:l), ops: []) { l }
      
      # Comparison expressions
      rule(left: simple(:l), comp: simple(:comparison)) do
        if comparison && comparison[:op] && comparison[:right]
          op_name = comparison[:op].keys.first
          Syntax::CallExpression.new(op_name, [l, comparison[:right]], loc: LOC)
        else
          l
        end
      end
      
      rule(left: simple(:l), comp: nil) { l }
      
      # Declarations
      rule(type: simple(:type), name: simple(:name)) do
        Syntax::InputDeclaration.new(name, nil, type.to_sym, [], loc: LOC)
      end
      
      rule(name: simple(:name), expr: simple(:expr)) do
        # This rule matches both value and trait declarations
        # We'll need to differentiate them somehow or handle them in post-processing
        Syntax::ValueDeclaration.new(name, expr, loc: LOC)
      end
      
      # Schema structure - convert the hash to Root node
      rule(input: { declarations: sequence(:input_decls) }, declarations: sequence(:other_decls)) do
        values = other_decls.select { |d| d.is_a?(Syntax::ValueDeclaration) }
        traits = other_decls.select { |d| d.is_a?(Syntax::TraitDeclaration) }
        Syntax::Root.new(input_decls, values, traits, loc: LOC)
      end
      
      rule(input: { declarations: simple(:input_decl) }, declarations: sequence(:other_decls)) do
        values = other_decls.select { |d| d.is_a?(Syntax::ValueDeclaration) }
        traits = other_decls.select { |d| d.is_a?(Syntax::TraitDeclaration) }
        Syntax::Root.new([input_decl], values, traits, loc: LOC)
      end
    end
  end
end