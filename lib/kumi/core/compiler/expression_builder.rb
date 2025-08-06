# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # Handles pure expression compilation with no runtime logic
      # Compiles syntax expressions into pure lambda functions
      class ExpressionBuilder
        def initialize(bindings)
          @bindings = bindings
        end

        # Main expression compilation method
        # Returns a lambda that when called with ctx, returns the expression value
        def compile(expr)
          case expr
          when Kumi::Syntax::CallExpression
            compile_call(expr)
          when Kumi::Syntax::CascadeExpression
            compile_cascade(expr)
          when Kumi::Syntax::InputElementReference
            compile_input_element_reference(expr)
          when Kumi::Syntax::InputReference
            compile_input_field_reference(expr)
          when Kumi::Syntax::DeclarationReference
            compile_declaration_reference(expr)
          when Kumi::Syntax::Literal
            compile_literal(expr)
          when Kumi::Syntax::ArrayExpression
            compile_array_expression(expr)
          else
            raise "Unknown expression type: #{expr.class}"
          end
        end

        private

        # Compile function call expression into pure lambda
        def compile_call(expr)
          fn = Kumi::Registry.fetch(expr.fn_name)
          arg_compilers = expr.args.map { |arg| compile(arg) }

          lambda do |ctx|
            args = arg_compilers.map { |compiler| compiler.call(ctx) }
            fn.call(*args)
          end
        end

        # Compile cascade expression (conditional logic) into pure lambda
        def compile_cascade(expr)
          conditional_cases = expr.cases.reject { |c| base_case?(c) }
          base_case = expr.cases.find { |c| base_case?(c) }

          condition_compilers = conditional_cases.map { |c| compile(c.condition) }
          result_compilers = conditional_cases.map { |c| compile(c.result) }
          base_compiler = base_case ? compile(base_case.result) : nil

          lambda do |ctx|
            condition_compilers.each_with_index do |cond_compiler, i|
              return result_compilers[i].call(ctx) if cond_compiler.call(ctx)
            end
            base_compiler&.call(ctx)
          end
        end

        # Compile nested input element reference into pure lambda
        def compile_input_element_reference(expr)
          raise "should use from AccessorBuilder"
        end

        # Compile simple input field reference into pure lambda
        def compile_input_field_reference(expr)
          raise "should use from AccessorBuilder"
        end

        # Compile declaration reference into pure lambda
        def compile_declaration_reference(expr)
          name = expr.name
          lambda do |ctx|
            fn = @bindings[name]
            return nil unless fn

            fn.call(ctx)
          end
        end

        # Compile literal value into pure lambda
        def compile_literal(expr)
          value = expr.value
          ->(_ctx) { value }
        end

        # Compile array expression into pure lambda
        def compile_array_expression(expr)
          element_compilers = expr.elements.map { |elem| compile(elem) }

          lambda do |ctx|
            element_compilers.map { |compiler| compiler.call(ctx) }
          end
        end

        # Helper to identify base cases in cascade expressions
        def base_case?(case_expr)
          case_expr.condition.is_a?(Kumi::Syntax::Literal) && case_expr.condition.value == true
        end
      end
    end
  end
end
