# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class DeclarationValidatorPass < VisitorPass
          reads :input_metadata
          writes

          def run(errors)
            # nil when run in isolation without the input collector; in that
            # case input-path checking is skipped (no tree to check against).
            @input_metadata = get_state(:input_metadata, required: false)
            each_decl do |decl|
              visit(decl) { |node| validate_node(node, errors) }
            end
            state
          end

          private

          def validate_node(node, errors)
            case node
            when Kumi::Syntax::ValueDeclaration
              validate_attribute(node, errors)
            when Kumi::Syntax::TraitDeclaration
              validate_trait(node, errors)
            when Kumi::Syntax::InputReference
              validate_input_path([node.name], node, errors)
            when Kumi::Syntax::InputElementReference
              validate_input_path(node.path, node, errors)
            end
          end

          # Walk a referenced input path against the declared input tree and
          # report a clean, located error at the first segment that doesn't
          # exist (or that is read past a leaf). Catching it here — before any
          # lowering — turns a typo'd `input.nope` into a user error instead of
          # a "please report" compiler bug deep in dimensional analysis.
          def validate_input_path(path, node, errors)
            return unless @input_metadata

            children = @input_metadata
            walked = []
            path.each do |seg|
              unless children.is_a?(Hash) && children.key?(seg)
                report(errors, undeclared_input_message(walked, seg, children), location: node.loc)
                break
              end

              walked << seg
              children = children[seg].children
            end
          end

          def undeclared_input_message(walked, seg, siblings)
            prefix = walked.empty? ? "input" : "input.#{walked.join('.')}"
            known = siblings.is_a?(Hash) ? siblings.keys : []
            if known.empty?
              "`#{prefix}.#{seg}` reads past a leaf input — `#{prefix}` has no field `#{seg}` (it has no sub-fields)."
            else
              "`#{prefix}.#{seg}` refers to an undeclared input — `#{prefix}` has no field `#{seg}`. " \
                "Available: #{known.map(&:to_s).join(', ')}."
            end
          end

          def validate_attribute(node, errors)
            return unless node.expression.nil?

            report_error(errors, "attribute `#{node.name}` requires an expression", location: node.loc)
          end

          def validate_trait(node, errors)
            return if node.expression.is_a?(Kumi::Syntax::CallExpression)

            report_error(errors, "trait `#{node.name}` must wrap a CallExpression", location: node.loc)
          end
        end
      end
    end
  end
end
