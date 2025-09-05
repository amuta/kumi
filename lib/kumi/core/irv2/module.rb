# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module IRV2
      class Module
        attr_reader :declarations, :metadata

        def initialize(declarations, metadata = {})
          @declarations = declarations
          @metadata = metadata
        end

        def to_s
          format_declaration_based
        end

        private

        def format_declaration_based
          output = []
          output << "; — Module: Declaration-Based IR"
          output << ""

          @declarations.each do |name, decl|
            output << "Declaration #{name} {"

            unless decl.parameters.empty?
              output << "  params:"
              decl.parameters.each do |param|
                case param[:type]
                when :input
                  output << "    #{param[:name]} : View(#{param[:dtype]}, axes=#{param[:axes]})"
                when :dependency
                  output << "    #{param[:name]} : View(#{param[:dtype]}, axes=#{param[:axes]})  ; #{param[:source]}"
                end
              end
            end

            output << "  operations: ["
            decl.operations.each do |op|
              comment = format_operation_comment(op)
              op_str = format_operation(op)
              padding = [50 - op_str.length, 1].max
              output << "    #{op_str}#{' ' * padding}; #{comment}"
            end
            output << "  ]"
            output << "  result: %#{decl.result.id}"
            output << "}"
            output << ""
          end

          # Add canonical inputs if available
          if @metadata.dig("analysis", "inputs")
            output << "; — Canonical Inputs"
            output << ""
            @metadata["analysis"]["inputs"].each do |input|
              path_str = input["path"].join(".")
              scope_str = input["scope"].empty? ? "[]" : "[#{input['scope'].join(', ')}]"
              output << "#{path_str}: #{input['dtype']} (scope=#{scope_str})"
            end
            output << ""
          end

          output.join("\n")
        end

        private

        def format_operation(val)
          case val.op
          when :LoadInput
            "%#{val.id} = LoadInput #{val.args.first.inspect}"
          when :LoadDeclaration
            "%#{val.id} = LoadDeclaration #{val.args.first.inspect}"
          when :LoadDecl
            "%#{val.id} = LoadDecl #{val.args.first.inspect}"
          when :Map
            args_str = val.args.map { |a| "%#{a.id}" }.join(", ")
            op_name = val.attrs[:fn] || "unknown"
            "%#{val.id} = Map(#{op_name}, #{args_str})"
          when :Reduce
            op_name = val.attrs[:fn] || "unknown"
            last_axis = val.attrs[:axis]
            "%#{val.id} = Reduce(#{op_name}, %#{val.args.first.id}, #{last_axis.inspect})"
          when :AlignTo
            axes_str = val.attrs[:target_axes].map(&:inspect).join(",")
            "%#{val.id} = AlignTo(%#{val.args.first.id}, [#{axes_str}])"
          when :ConstructTuple
            args_str = val.args.map { |a| "%#{a.id}" }.join(", ")
            "%#{val.id} = ConstructTuple(#{args_str})"
          else
            val.to_s
          end
        end

        def format_operation_comment(val)
          # Extract dimensional information from metadata if available
          scope = metadata.dig(:operation_scopes, val.id) || []
          dtype = metadata.dig(:operation_types, val.id) || :unknown

          scope_str = scope.empty? ? "[]" : "[#{scope.map(&:inspect).join(',')}]"
          "#{scope_str}, #{dtype}"
        end
      end
    end
  end
end
