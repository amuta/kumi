# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class AttachAnchorsPass < PassBase
          reads :snast_module
          writes :anchor_by_decl

          NAST = Kumi::Core::NAST

          def run(_errors)
            @snast = get_state(:snast_module, required: true)

            out = {}
            @snast.decls.each do |name, decl|
              out[name] ||= {}

              wanted = axes_of(decl)
              wanted = axes_of(decl.body) if wanted.empty?

              # No anchors needed for scalars (rank-0)
              next if wanted.empty?

              out[name][wanted] = pick_anchor_fqn(decl.body, wanted)
            end

            state.with(:anchor_by_decl, out.freeze)
          end

          private

          def pick_anchor_fqn(node, wanted_axes)
            return nil if Array(wanted_axes).empty?

            found = nil
            walk = lambda do |x|
              case x
              when NAST::InputRef
                ax = axes_of(x)
                found ||= ir_fqn(x) if prefix?(wanted_axes, ax)
              when NAST::Ref
                decl = @snast.decls.fetch(x.name) { raise "unknown declaration #{x.name}" }
                walk.call(decl.body)
              when NAST::IndexRef
                found ||= x.input_fqn
              else
                x.children.each { |child| walk.call(child) }
              end
            end

            walk.call(node)
            found or raise "no anchor for axes #{wanted_axes.inspect}"
          end

          def axes_of(n) = Array(n.meta[:stamp]&.dig(:axes))
          def prefix?(pre, full) = pre.each_with_index.all? { |tok, i| full[i] == tok }
          def ir_fqn(n) = n.instance_variable_get(:@fqn) || n.path.join(".")
        end
      end
    end
  end
end
