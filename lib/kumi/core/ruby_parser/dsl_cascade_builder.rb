# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      class DslCascadeBuilder
        include Syntax

        attr_reader :cases

        def initialize(context, loc)
          @context = context
          @cases   = []
          @loc = loc
        end

        def on(*args)
          validate_on_args(args, "on", @loc)

          trait_names = args[0..-2]
          expr = args.last

          trait_bindings = convert_trait_names_to_bindings(trait_names, @loc)
          condition = @context.fn(:cascade_and, *trait_bindings)
          result = ensure_syntax(expr)
          add_case(condition, result)
        end

        def on_any(*args)
          validate_on_args(args, "on_any", @loc)

          trait_names = args[0..-2]
          expr = args.last

          trait_bindings = convert_trait_names_to_bindings(trait_names, @loc)
          condition = create_fn(:any?, trait_bindings)
          result = ensure_syntax(expr)
          add_case(condition, result)
        end

        def on_none(*args)
          validate_on_args(args, "on_none", @loc)

          trait_names = args[0..-2]
          expr = args.last

          trait_bindings = convert_trait_names_to_bindings(trait_names, @loc)
          condition = create_fn(:none?, trait_bindings)
          result = ensure_syntax(expr)
          add_case(condition, result)
        end

        def base(expr)
          result = ensure_syntax(expr)
          add_case(create_literal(true), result)
        end

        def method_missing(method_name, *args, &)
          return super if !args.empty? || block_given?

          # Allow direct trait references in cascade conditions
          create_binding(method_name, @loc)
        end

        def respond_to_missing?(_method_name, _include_private = false)
          true
        end

        private

        def validate_on_args(args, method_name, location)
          raise_error("cascade '#{method_name}' requires at least one trait name", location) if args.empty?

          return unless args.size == 1

          raise_error("cascade '#{method_name}' requires an expression as the last argument", location)
        end

        def convert_trait_names_to_bindings(trait_names, location)
          trait_names.map do |name|
            case name
            when Symbol
              create_binding(name, location)
            when DeclarationReference
              name # Already a binding from method_missing
            else
              # TODO: MOVE THESE TO ANALYZER- GRAMMAR CHECKS!
              case name
              when Kumi::Syntax::CallExpression
                if name.fn_name == :==
                  raise_error(
                    "cascade conditions must be bare trait identifiers, not expressions like 'ref(...) == ...'. " \
                    "Use fn(:==, ref(:tier), \"gold\") or define the comparison as a separate trait.",
                    location
                  )
                else
                  raise_error(
                    "cascade conditions must be bare trait identifiers, not function calls (CallExpression). " \
                    "Define the function call as a separate trait first.",
                    location
                  )
                end
              when Kumi::Syntax::DeclarationReference
                raise_error(
                  "cascade conditions must be bare trait identifiers, not value references (DeclarationReference). " \
                  "Use just 'my_trait' instead of 'ref(:my_trait)'.",
                  location
                )
              else
                expression_type = name.class.name.split("::").last
                raise_error(
                  "cascade conditions must be bare trait identifiers, not #{expression_type} expressions. " \
                  "Define complex expressions as separate traits first.",
                  location
                )
              end
            end
          end
        end

        def add_case(condition, result)
          @cases << Kumi::Syntax::CaseExpression.new(condition, result)
        end

        def ref(name)
          @context.ref(name)
        end

        def fn(name, *args)
          @context.fn(name, *args)
        end

        def create_literal(value)
          @context.literal(value)
        end

        def create_fn(name, args)
          @context.fn(name, args)
        end

        def input
          @context.input
        end

        def ensure_syntax(expr)
          @context.ensure_syntax(expr)
        end

        def raise_error(message, location)
          @context.raise_error(message, location)
        end

        def create_binding(name, location)
          Kumi::Syntax::DeclarationReference.new(name, loc: location)
        end
      end
    end
  end
end
