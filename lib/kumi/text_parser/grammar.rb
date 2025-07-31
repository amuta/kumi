# frozen_string_literal: true

require "parslet"

module Kumi
  module TextParser
    # Parslet grammar with proper arithmetic operator precedence  
    class Grammar < Parslet::Parser
      # Basic tokens
      rule(:space) { match('\s').repeat(1) }
      rule(:space?) { space.maybe }
      rule(:newline?) { match('\n').maybe }
      
      # Identifiers and symbols
      rule(:identifier) { match('[a-zA-Z_]') >> match('[a-zA-Z0-9_]').repeat }
      rule(:symbol) { str(':') >> identifier.as(:symbol) }
      
      # Literals
      rule(:integer) { match('[0-9]').repeat(1) }
      rule(:float) { integer >> str('.') >> match('[0-9]').repeat(1) }
      rule(:number) { float.as(:float) | integer.as(:integer) }
      rule(:string_literal) { 
        str('"') >> (str('"').absent? >> any).repeat.as(:string) >> str('"') 
      }
      rule(:boolean) { (str('true').as(:true) | str('false').as(:false)) }
      rule(:literal) { number | string_literal | boolean }
      
      # Keywords
      rule(:schema_kw) { str('schema') }
      rule(:input_kw) { str('input') }
      rule(:value_kw) { str('value') }
      rule(:trait_kw) { str('trait') }
      rule(:do_kw) { str('do') }
      rule(:end_kw) { str('end') }
      
      # Type keywords
      rule(:type_name) { 
        str('integer') | str('float') | str('string') | str('boolean') | str('any')
      }
      
      # Operators (ordered by precedence, highest to lowest)
      rule(:mult_op) { str('*').as(:multiply) | str('/').as(:divide) | str('%').as(:modulo) }
      rule(:add_op) { str('+').as(:add) | str('-').as(:subtract) }
      rule(:comp_op) { 
        str('>=').as(:>=) | str('<=').as(:<=) | str('==').as(:==) | 
        str('!=').as(:!=) | str('>').as(:>) | str('<').as(:<) 
      }
      rule(:logical_and_op) { str('&').as(:and) }
      rule(:logical_or_op) { str('|').as(:or) }
      
      # Expressions with proper precedence (using left recursion elimination)
      rule(:primary_expr) {
        str('(') >> space? >> expression >> space? >> str(')') |
        function_call |
        input_reference |
        declaration_reference |
        literal
      }
      
      # Function calls: fn(:name, arg1, arg2, ...)
      rule(:function_call) {
        str('fn(') >> space? >> 
        symbol.as(:fn_name) >>
        (str(',') >> space? >> expression).repeat(0).as(:args) >>
        space? >> str(')')
      }
      
      # Multiplication/Division (left-associative)
      rule(:mult_expr) {
        primary_expr.as(:left) >> 
        (space? >> mult_op.as(:op) >> space? >> primary_expr.as(:right)).repeat.as(:ops)
      }
      
      # Addition/Subtraction (left-associative) 
      rule(:add_expr) {
        mult_expr.as(:left) >>
        (space? >> add_op.as(:op) >> space? >> mult_expr.as(:right)).repeat.as(:ops)
      }
      
      # Comparison operators
      rule(:comp_expr) {
        add_expr.as(:left) >>
        (space? >> comp_op.as(:op) >> space? >> add_expr.as(:right)).maybe.as(:comp)
      }
      
      # Logical AND (higher precedence than OR)
      rule(:logical_and_expr) {
        comp_expr.as(:left) >>
        (space? >> logical_and_op.as(:op) >> space? >> comp_expr.as(:right)).repeat.as(:ops)
      }
      
      # Logical OR (lowest precedence)
      rule(:logical_or_expr) {
        logical_and_expr.as(:left) >>
        (space? >> logical_or_op.as(:op) >> space? >> logical_and_expr.as(:right)).repeat.as(:ops)
      }
      
      rule(:expression) { logical_or_expr }
      
      # Input references: input.field or input.field.subfield
      rule(:input_reference) {
        str('input.') >> input_path.as(:input_ref)
      }
      
      rule(:input_path) {
        identifier >> (str('.') >> identifier).repeat
      }
      
      # Declaration references: just identifier
      rule(:declaration_reference) {
        identifier.as(:decl_ref)
      }
      
      # Input declarations
      rule(:input_declaration) {
        nested_array_declaration | simple_input_declaration
      }
      
      rule(:simple_input_declaration) {
        space? >> type_name.as(:type) >> space >> symbol.as(:name) >> 
        (str(',') >> space? >> domain_spec).maybe.as(:domain) >> space? >> newline?
      }
      
      rule(:nested_array_declaration) {
        space? >> str('array') >> space >> symbol.as(:name) >> space >> do_kw >> space? >> newline? >>
        input_declaration.repeat.as(:nested_fields) >>
        space? >> end_kw >> space? >> newline?
      }
      
      rule(:domain_spec) {
        str('domain:') >> space? >> domain_value.as(:domain_value)
      }
      
      rule(:domain_value) {
        # Ranges: 1..10, 1...10, 0.0..100.0
        range_value | 
        # Word arrays: %w[active inactive]
        word_array_value |
        # String arrays: ["active", "inactive"] 
        string_array_value
      }
      
      rule(:range_value) {
        (float | integer) >> str('..') >> (float | integer)
      }
      
      rule(:word_array_value) {
        str('%w[') >> (identifier >> space?).repeat.as(:words) >> str(']')
      }
      
      rule(:string_array_value) {
        str('[') >> space? >> 
        (string_literal >> (str(',') >> space? >> string_literal).repeat).maybe >>
        space? >> str(']')
      }
      
      # Value declarations
      rule(:value_declaration) {
        cascade_value_declaration | simple_value_declaration
      }
      
      rule(:simple_value_declaration) {
        space? >> value_kw >> space >> symbol.as(:name) >> str(',') >> space? >>
        expression.as(:expr) >> space? >> newline?
      }
      
      rule(:cascade_value_declaration) {
        space? >> value_kw >> space >> symbol.as(:name) >> space >> do_kw >> space? >> newline? >>
        cascade_case.repeat.as(:cases) >>
        space? >> end_kw >> space? >> newline?
      }
      
      rule(:cascade_case) {
        (space? >> str('on') >> space >> identifier.as(:condition) >> str(',') >> space? >> 
         expression.as(:result) >> space? >> newline?) |
        (space? >> str('base') >> space >> expression.as(:base_result) >> space? >> newline?)
      }
      
      # Trait declarations  
      rule(:trait_declaration) {
        space? >> trait_kw >> space >> symbol.as(:name) >> str(',') >> space? >>
        expression.as(:expr) >> space? >> newline?
      }
      
      # Input block
      rule(:input_block) {
        space? >> input_kw >> space >> do_kw >> space? >> newline? >>
        input_declaration.repeat.as(:declarations) >>
        space? >> end_kw >> space? >> newline?
      }
      
      # Schema structure
      rule(:schema_body) {
        input_block.as(:input) >>
        (value_declaration | trait_declaration).repeat.as(:declarations)
      }
      
      rule(:schema) {
        space? >> schema_kw >> space >> do_kw >> space? >> newline? >>
        schema_body >>
        space? >> end_kw >> space?
      }
      
      root(:schema)
    end
  end
end