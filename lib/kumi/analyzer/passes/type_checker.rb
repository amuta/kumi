# frozen_string_literal: true

# RESPONSIBILITY:
#   - Validate function call arity and argument types against the FunctionRegistry.
module Kumi
  module Analyzer
    module Passes
      class TypeChecker < Visitor
        def initialize(schema, state)
          @schema = schema
          @state = state
        end

        def run(errors)
          each_decl do |decl|
            visit(decl) { |node| handle(node, errors) }
          end
        end

        private

        def handle(node, errors)
          validate_call(node, errors) if node.is_a?(CallExpression)
        end

        def validate_call(node, errors)
          sig = Kumi::FunctionRegistry.signature(node.fn_name)

          if sig[:arity] >= 0 && sig[:arity] != node.args.size
            errors << [node.loc, "operator `#{node.fn_name}` expects #{sig[:arity]} args, got #{node.args.size}"]
          end

          return if sig[:types].nil? || (sig[:arity].negative? && node.args.empty?)

          node.args.each_with_index do |arg, i|
            next unless arg.is_a?(Literal)

            req_type = sig[:types][i]
            next if req_type.nil? || req_type == :any

            arg_type = arg.value.class.name.downcase.to_sym
            arg_type = :numeric if %i[integer float].include?(arg_type)
            arg_type = :string if arg_type == :regexp

            unless Array(req_type).include?(arg_type)
              errors << [arg.loc,
                         "argument #{i + 1} of `fn(:#{node.fn_name})` expects #{Array(req_type).join(' or ')}, got literal `#{arg.value}` of type #{arg_type}"]
            end
          end
        rescue Kumi::FunctionRegistry::UnknownFunction
          errors << [node.loc, "unsupported operator `#{node.fn_name}`"]
        end

        def each_decl(&b)
          @schema.attributes.each(&b)
          @schema.traits.each(&b)
        end
      end
    end
  end
end
