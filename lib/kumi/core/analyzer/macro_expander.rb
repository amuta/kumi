# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      # Takes a function's `expand` template and pre-normalized NAST arguments,
      # and recursively builds a new NAST tree representing the expansion.
      class MacroExpander
        NAST = Kumi::Core::NAST

        def self.expand(func, normalized_args, loc, errors)
          new(func, normalized_args, loc, errors).expand
        end

        def initialize(func, normalized_args, loc, errors)
          @func = func
          @normalized_args = normalized_args
          @loc = loc
          @errors = errors
        end

        def expand
          build_nast_node(@func.expand)
        end

        private

        def build_nast_node(template_part)
          case template_part
          when Hash
            if template_part.key?("fn")
              build_call_node(template_part)
            elsif template_part.key?("const")
              NAST::Const.new(value: template_part["const"], loc: @loc)
            else
              raise "Invalid expansion template part: #{template_part}"
            end
          when String
            build_argument_node(template_part)
          else
            raise "Invalid expansion template part: #{template_part}"
          end
        end

        def build_call_node(template_hash)
          new_args = template_hash.fetch("args", []).map do |arg_template|
            build_nast_node(arg_template)
          end

          NAST::Call.new(
            fn: template_hash.fetch("fn"),
            args: new_args,
            loc: @loc
          )
        end

        def build_argument_node(arg_str)
          raise "Invalid argument placeholder: #{arg_str}" unless arg_str.start_with?("$")

          index = arg_str[1..].to_i - 1
          @normalized_args.fetch(index) do
            @errors << "Expansion for #{@func.id} requires at least #{index + 1} arguments."
            NAST::Const.new(value: nil, loc: @loc)
          end
        end
      end
    end
  end
end
