# frozen_string_literal: true

require_relative "../syntax/node"
require_relative "../syntax/root"
require_relative "../syntax/input_declaration"
require_relative "../syntax/value_declaration"
require_relative "../syntax/trait_declaration"
require_relative "../syntax/call_expression"
require_relative "../syntax/input_reference"
require_relative "../syntax/input_element_reference"
require_relative "../syntax/declaration_reference"
require_relative "../syntax/literal"
require_relative "../syntax/cascade_expression"
require_relative "../syntax/case_expression"
require_relative "../syntax/array_expression"
require_relative "../error_reporting"

module Kumi
  module TextParser
    # Text parser that produces identical AST to Ruby DSL parser
    # Directly parses text and constructs AST nodes
    class Parser
      include Kumi::ErrorReporting
      
      def initialize
        @tokens = []
        @position = 0
        @source_file = "<text_parser>"
      end

      def parse(text_dsl, source_file: "<text_parser>")
        @source_file = source_file
        @original_text = text_dsl
        
        # Tokenize the input
        @tokens = tokenize(text_dsl)
        @position = 0

        # Parse the schema structure
        parse_schema
      end

      private

      def tokenize(text)
        # Enhanced tokenization with location tracking
        @original_lines = text.lines
        @lines = []
        @line_locations = []
        
        @original_lines.each_with_index do |line, line_number|
          stripped = line.strip
          next if stripped.empty?
          
          @lines << stripped
          @line_locations << create_location(line_number + 1, 1) # 1-based line numbers
        end
        
        @line_index = 0
        []  # We'll parse directly from lines instead of pre-tokenizing
      end

      def parse_line_tokens(line)
        tokens = []
        parts = line.split(/\s+/)
        
        parts.each_with_index do |part, idx|
          case part
          when 'schema', 'input', 'value', 'trait'
            tokens << { type: :keyword, value: part.to_sym }
          when 'do'
            tokens << { type: :do, value: 'do' }
          when /^:(\w+)$/
            tokens << { type: :symbol, value: $1.to_sym }
          else
            tokens << { type: :word, value: part } unless part.empty?
          end
        end

        tokens
      end

      def parse_declaration_line(line)
        # Parse lines like "integer :age, domain: 18..65" or "array :items, elem: { type: :float }"
        if match = line.match(/^(\w+)\s+:(\w+)(?:,\s*(.+))?$/)
          method_name = match[1]
          field_name = match[2].to_sym
          options_str = match[3]

          tokens = [
            { type: :method, value: method_name.to_sym },
            { type: :symbol, value: field_name }
          ]

          if options_str
            tokens.concat(parse_options(options_str, method_name))
          end

          tokens
        end
      end

      def parse_options(options_str, method_name = nil)
        # Parse options like "domain: 18..65", "elem: { type: :float }", etc.
        tokens = []
        
        # Handle domain options
        if match = options_str.match(/domain:\s*(.+?)(?:,|$)/)
          domain_value = match[1].strip
          
          # Parse different domain types
          if domain_value.match(/^\d+\.\.\.\d+$/) # exclusive range
            start_val, end_val = domain_value.split('...').map(&:to_i)
            tokens << { type: :domain, value: Range.new(start_val, end_val, true) }
          elsif domain_value.match(/^\d+\.\.\d+$/) # inclusive range  
            start_val, end_val = domain_value.split('..').map(&:to_i)
            tokens << { type: :domain, value: Range.new(start_val, end_val, false) }
          elsif domain_value.match(/^\d+\.\d+\.\.\d+\.\d+$/) # float range
            start_val, end_val = domain_value.split('..').map(&:to_f)
            tokens << { type: :domain, value: Range.new(start_val, end_val, false) }
          elsif domain_value.match(/^%w\[([^\]]+)\]$/) # word array
            words = $1.split(/\s+/)
            tokens << { type: :domain, value: words }
          elsif domain_value.match(/^\[([^\]]+)\]$/) # regular array
            # This is simplified - in practice you'd parse the array properly
            array_content = $1
            if array_content.match(/^"[^"]*"(?:,\s*"[^"]*")*$/) # string array
              strings = array_content.scan(/"([^"]*)"/).flatten
              tokens << { type: :domain, value: strings }
            end
          end
        end
        
        # Handle elem options for arrays
        if match = options_str.match(/elem:\s*\{\s*type:\s*:(\w+)\s*\}/)
          elem_type = match[1].to_sym
          tokens << { type: :elem_type, value: elem_type }
        end

        tokens
      end

      def parse_value_trait_line(line)
        # Parse lines like "value :subtotal, fn(:multiply, input.price, input.quantity)"
        tokens = []
        
        if match = line.match(/^(value|trait)\s+:(\w+),\s*(.+)$/)
          keyword = match[1].to_sym
          name = match[2].to_sym
          expression_str = match[3].strip
          
          tokens << { type: :keyword, value: keyword }
          tokens << { type: :symbol, value: name }
          tokens << { type: :expression, value: expression_str }
        end
        
        tokens
      end

      def parse_schema
        # Find schema line and parse its content
        schema_line_index = find_schema_line
        unless schema_line_index
          raise_parse_error("Missing 'schema do' declaration. Schema must start with 'schema do'")
        end

        @line_index = schema_line_index + 1
        skip_line_if_matches(/^do$/)

        # Parse schema body using line-by-line approach
        inputs = []
        values = []
        traits = []

        while @line_index < @lines.length
          line = current_line
          break if line.match(/^end$/)

          case line
          when /^input\s+do$/
            inputs.concat(parse_input_block_content)
          when /^value\s+:(\w+)(\s+do|,)/
            # Handle both "value :name, expr" and "value :name do" patterns
            values << parse_value_declaration_from_line(line)
            # Don't advance_line here - let parse_value_declaration_from_line handle it based on type
          when /^trait\s+:/
            traits << parse_trait_declaration_from_line(line)
            advance_line
          when /^(value|trait)\s*$/
            # Catch malformed value/trait declarations without proper syntax
            type = line.match(/^(value|trait)/)[1]
            raise_parse_error("Invalid #{type} declaration: '#{line}'. Expected format: '#{type} :name, expression'")
          else
            # Skip lines that don't match expected patterns (could be comments, etc.)
            advance_line
          end
        end

        # Build the Root AST node with location
        Syntax::Root.new(inputs, values, traits, loc: create_location(1, 1))
      end

      def parse_input_block_content
        # MODE 1: Parse input block content - type-specific DSL methods
        advance_line # skip 'input do'
        declarations = []

        while @line_index < @lines.length
          line = current_line
          break if line.match(/^end$/)

          # Parse input DSL lines like: integer :age, domain: 0..120
          if declaration = parse_input_dsl_line(line)
            declarations << declaration
            # Special case: nested array blocks handle their own line advancement
            unless line.match(/^array\s+:\w+\s+do$/)
              advance_line
            end
          else
            advance_line
          end
        end

        advance_line if current_line&.match(/^end$/) # skip 'end'
        declarations
      end

      def parse_input_dsl_line(line)
        # MODE 1: Parse input DSL line like "integer :age, domain: 0..120"
        # or "array :items do" (nested block)
        return nil if line.strip.empty?

        # Check for nested array block: "array :field_name do"
        if match = line.match(/^array\s+:(\w+)\s+do$/)
          field_name = match[1].to_sym
          return parse_nested_array_block(field_name)
        end

        # Parse the basic structure: method_name :field_name, options
        match = line.match(/^(\w+)\s+:(\w+)(?:\s*,\s*(.+))?$/)
        unless match
          raise_parse_error("Invalid input declaration syntax: '#{line}'. Expected format: 'type :field_name' or 'type :field_name, options'")
        end

        method_name = match[1].to_sym  # :integer, :string, :array, etc.
        field_name = match[2].to_sym
        options_str = match[3]
        
        # Validate known types
        valid_types = [:integer, :float, :string, :boolean, :array, :hash, :any]
        unless valid_types.include?(method_name)
          raise_parse_error("Unknown type '#{method_name}'. Valid types are: #{valid_types.join(', ')}")
        end

        # Parse options (domain, elem, etc.)
        domain = nil
        elem_type = nil

        if options_str
          # Parse domain
          if domain_match = options_str.match(/domain:\s*(.+?)(?:,|$)/)
            domain = parse_domain_value(domain_match[1].strip)
          end

          # Parse array element type
          if elem_match = options_str.match(/elem:\s*\{\s*type:\s*:(\w+)\s*\}/)
            elem_type = elem_match[1].to_sym
          end
        end

        # Determine final type
        final_type = if method_name == :array && elem_type
                       { array: elem_type }
                     else
                       method_name
                     end

        # Create InputDeclaration node with location
        Syntax::InputDeclaration.new(field_name, domain, final_type, [], loc: current_location)
      end

      def parse_nested_array_block(field_name)
        # Parse nested array block structure:
        # array :line_items do
        #   float   :price
        #   integer :quantity  
        #   array :nested_items do
        #     string :name
        #   end
        # end
        advance_line # skip the "array :field do" line
        
        nested_fields = []
        while @line_index < @lines.length
          line = current_line
          break if line.match(/^end$/)
          
          # Use MODE 1 parsing inside array blocks (same as input block parsing)
          if nested_field = parse_array_nested_field(line)
            nested_fields << nested_field
            # Special case: nested array blocks handle their own line advancement
            unless line.match(/^array\s+:\w+\s+do$/)
              advance_line
            end
          else
            advance_line
          end
        end
        
        advance_line if current_line&.match(/^end$/) # skip 'end'
        
        # Create InputDeclaration with nested structure  
        # Use :array as type, same as Ruby DSL, with nested_fields as children
        Syntax::InputDeclaration.new(field_name, nil, :array, nested_fields, loc: current_location)
      end
      
      def parse_array_nested_field(line)
        # MODE 1 inside array blocks: Parse like input DSL but for nested fields
        return nil if line.strip.empty?

        # Check for nested array block: "array :field_name do"
        if match = line.match(/^array\s+:(\w+)\s+do$/)
          field_name = match[1].to_sym
          return parse_nested_array_block(field_name)
        end

        # Parse the basic structure: method_name :field_name, options
        match = line.match(/^(\w+)\s+:(\w+)(?:\s*,\s*(.+))?$/)
        unless match
          raise_parse_error("Invalid nested field declaration syntax: '#{line}'. Expected format: 'type :field_name' or 'type :field_name, options'")
        end

        method_name = match[1].to_sym  # :integer, :string, :float, etc.
        field_name = match[2].to_sym
        options_str = match[3]
        
        # Validate known types for nested fields
        valid_types = [:integer, :float, :string, :boolean, :any]
        unless valid_types.include?(method_name)
          raise_parse_error("Unknown nested field type '#{method_name}'. Valid types are: #{valid_types.join(', ')}")
        end

        # Parse options (domain, etc.)
        domain = nil
        if options_str
          # Parse domain
          if domain_match = options_str.match(/domain:\s*(.+?)(?:,|$)/)
            domain = parse_domain_value(domain_match[1].strip)
          end
        end

        # Create InputDeclaration node with location
        Syntax::InputDeclaration.new(field_name, domain, method_name, [], loc: current_location)
      end
      

      def parse_value_declaration_from_line(line)
        # MODE 2: Parse value declaration line like "value :total, fn(:add, input.a, input.b)"
        # or "value :name do" (cascade block)
        
        # Check for cascade block: "value :name do"
        if match = line.match(/^value\s+:(\w+)\s+do$/)
          name = match[1].to_sym
          return parse_cascade_block(name)
          # Note: parse_cascade_block handles its own line advancement
        end
        
        # Regular value declaration
        match = line.match(/^value\s+:(\w+),\s*(.+)$/)
        unless match
          raise_parse_error("Invalid value declaration syntax: '#{line}'. Expected format: 'value :name, expression' or 'value :name do'")
        end

        name = match[1].to_sym
        expression_str = match[2].strip

        expr = parse_expression_string(expression_str)
        # Advance line for regular expressions (cascade blocks handle their own advancement)
        advance_line
        Syntax::ValueDeclaration.new(name, expr, loc: current_location)
      end
      
      def parse_cascade_block(name)
        # Parse cascade block structure:
        # value :discount_rate do
        #   on premium, 0.20
        #   on standard, 0.10
        #   base 0.05
        # end
        advance_line # skip the "value :name do" line
        
        cases = []
        base_result = nil
        
        while @line_index < @lines.length
          line = current_line
          break if line.match(/^end$/)
          
          # Parse "on condition, result" lines
          if match = line.match(/^on\s+(\w+),\s*(.+)$/)
            condition_name = match[1].to_sym
            result_str = match[2].strip
            
            # Create condition reference (trait reference)
            trait_ref = Syntax::DeclarationReference.new(condition_name, loc: current_location)
            
            # Wrap in ArrayExpression as Ruby DSL does
            array_expr = Syntax::ArrayExpression.new([trait_ref], loc: current_location)
            
            # Create all? function call with the array
            condition = Syntax::CallExpression.new(:all?, [array_expr], loc: current_location)
            
            # Parse the result expression
            result = parse_expression_string(result_str)
            
            # Create case expression
            case_expr = Syntax::CaseExpression.new(condition, result, loc: current_location)
            cases << case_expr
            
          # Parse "base result" line
          elsif match = line.match(/^base\s+(.+)$/)
            base_result_str = match[1].strip
            base_result = parse_expression_string(base_result_str)
          end
          
          advance_line
        end
        
        advance_line if current_line&.match(/^end$/) # skip 'end'
        
        # Add base case if present
        if base_result
          base_case = Syntax::CaseExpression.new(
            Syntax::Literal.new(true, loc: current_location), # base condition is always true
            base_result,
            loc: current_location
          )
          cases << base_case
        end
        
        # Create cascade expression
        cascade_expr = Syntax::CascadeExpression.new(cases, loc: current_location)
        Syntax::ValueDeclaration.new(name, cascade_expr, loc: current_location)
      end

      def parse_trait_declaration_from_line(line)
        # MODE 2: Parse trait declaration line like "trait :adult, (input.age >= 18)"
        match = line.match(/^trait\s+:(\w+),\s*(.+)$/)
        unless match
          raise_parse_error("Invalid trait declaration syntax: '#{line}'. Expected format: 'trait :name, expression'")
        end

        name = match[1].to_sym
        expression_str = match[2].strip

        expr = parse_expression_string(expression_str)
        Syntax::TraitDeclaration.new(name, expr, loc: current_location)
      end

      def build_empty_root
        Syntax::Root.new([], [], [], loc: create_location(1, 1))
      end

      def parse_expression_string(expr_str)
        # Parse expression strings like "fn(:multiply, input.price, input.quantity)"
        # or "(input.price > 100.0)" or "input.price * input.quantity"
        
        expr_str = expr_str.strip
        
        # Handle function calls: fn(:name, arg1, arg2, ...)
        # Allow function names with question marks like contains?
        if match = expr_str.match(/^fn\(:(\w+\??),\s*(.+)\)$/)
          func_name = match[1].to_sym
          args_str = match[2]
          args = parse_function_arguments(args_str)
          return Syntax::CallExpression.new(func_name, args, loc: current_location)
        end
        
        # Handle parenthesized expressions: (input.field > value)
        if match = expr_str.match(/^\((.+)\)$/)
          inner_expr = match[1].strip
          return parse_arithmetic_expression(inner_expr)
        end
        
        # Try to parse as arithmetic/comparison expression (even without parentheses)
        if contains_operator?(expr_str)
          return parse_arithmetic_expression(expr_str)
        end
        
        # Handle input references: input.field or input.field.subfield.subsubfield...
        if match = expr_str.match(/^input\.(.+)$/)
          path_str = match[1]
          # Split by dots to get the full path
          path = path_str.split('.').map(&:to_sym)
          
          # For single-level access like input.field, use InputReference
          if path.length == 1
            return Syntax::InputReference.new(path[0], loc: current_location)
          else
            # For multi-level access like input.field.subfield, use InputElementReference
            return Syntax::InputElementReference.new(path, loc: current_location)
          end
        end
        
        # Handle declaration references (values/traits): just the name
        if expr_str.match(/^[a-zA-Z_]\w*$/) && !%w[true false].include?(expr_str)
          return Syntax::DeclarationReference.new(expr_str.to_sym, loc: current_location)
        end
        
        # Handle literals
        if expr_str.match(/^\d+(_\d+)*\.\d+(_\d+)*$/) # float with underscores
          return Syntax::Literal.new(expr_str.gsub('_', '').to_f, loc: current_location)
        elsif expr_str.match(/^\d+\.\d+$/) # float
          return Syntax::Literal.new(expr_str.to_f, loc: current_location)
        elsif expr_str.match(/^\d+(_\d+)*$/) # integer with underscores
          return Syntax::Literal.new(expr_str.gsub('_', '').to_i, loc: current_location)
        elsif expr_str.match(/^\d+$/) # integer
          return Syntax::Literal.new(expr_str.to_i, loc: current_location)
        elsif expr_str.match(/^".*"$/) # string
          return Syntax::Literal.new(expr_str[1..-2], loc: current_location) # remove quotes
        elsif expr_str == "true"
          return Syntax::Literal.new(true, loc: current_location)
        elsif expr_str == "false"
          return Syntax::Literal.new(false, loc: current_location)
        end
        
        # Default fallback
        Syntax::Literal.new(expr_str, loc: current_location)
      end

      def parse_function_arguments(args_str)
        # Parse function arguments like "input.price, input.quantity"
        args = []
        
        # Simple argument parsing - split by comma and parse each
        arg_parts = args_str.split(',').map(&:strip)
        
        arg_parts.each do |arg|
          args << parse_expression_string(arg)
        end
        
        args
      end

      def parse_arithmetic_expression(expr_str)
        # Parse expressions like "input.price > 100.0" or "input.price * input.quantity"
        operators = ['>=', '<=', '==', '!=', '>', '<', '*', '+', '-', '/']
        
        operators.each do |op|
          if parts = expr_str.split(" #{op} ")
            if parts.length == 2
              left = parse_expression_string(parts[0].strip)
              right = parse_expression_string(parts[1].strip)
              
              # Map operators to function names for arithmetic
              func_name = case op
                          when '*' then :multiply
                          when '+' then :add
                          when '-' then :subtract
                          when '/' then :divide
                          else op.to_sym
                          end
              
              return Syntax::CallExpression.new(func_name, [left, right], loc: current_location)
            end
          end
        end
        
        # If no operator found, treat as simple expression
        parse_expression_string(expr_str)
      end

      def contains_operator?(expr_str)
        # Check if expression contains arithmetic or comparison operators
        operators = ['>=', '<=', '==', '!=', '>', '<', '*', '+', '-', '/']
        operators.any? { |op| expr_str.include?(" #{op} ") }
      end

      def parse_domain_value(domain_str)
        # Parse domain values like "0..120", "%w[active inactive]", "0.0..Float::INFINITY", etc.
        
        # Handle ranges with possible Float::INFINITY
        if domain_str.match(/^(.+)\.\.(.+)$/)
          start_str = $1.strip
          end_str = $2.strip
          
          # Parse start value
          start_val = parse_range_value(start_str)
          # Parse end value
          end_val = parse_range_value(end_str)
          
          return Range.new(start_val, end_val, false)
        elsif domain_str.match(/^%w\[([^\]]+)\]$/) # word array
          words = $1.split(/\s+/)
          words
        elsif domain_str.match(/^\[([^\]]+)\]$/) # regular array
          array_content = $1
          if array_content.match(/^"[^"]*"(?:,\s*"[^"]*")*$/) # string array
            array_content.scan(/"([^"]*)"/).flatten
          end
        else
          domain_str # fallback
        end
      end
      
      def parse_range_value(value_str)
        case value_str
        when "Float::INFINITY"
          Float::INFINITY
        when /^-?\d+\.\d+$/
          value_str.to_f
        when /^-?\d+$/
          value_str.to_i
        else
          value_str
        end
      end

      # Helper methods for line navigation
      def current_line
        @lines[@line_index]
      end

      def advance_line
        @line_index += 1
      end

      def find_schema_line
        @lines.each_with_index do |line, idx|
          return idx if line.match(/^schema\s+do$/)
        end
        nil
      end

      def skip_line_if_matches(pattern)
        if current_line&.match(pattern)
          advance_line
        end
      end
      
      # Location tracking helpers
      def create_location(line, column)
        Syntax::Location.new(file: @source_file, line: line, column: column)
      end
      
      def current_location
        return create_location(1, 1) if @line_locations.empty? || @line_index >= @line_locations.length
        @line_locations[@line_index]
      end
      
      def raise_parse_error(message)
        raise_syntax_error(message, location: current_location)
      end
    end
  end
end