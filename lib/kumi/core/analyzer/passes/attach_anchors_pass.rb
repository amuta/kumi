# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class AttachAnchorsPass < PassBase
          reads :snast_module
          optional_reads :cross_axes, :outer_axes
          writes :anchor_by_decl

          NAST = Kumi::Core::NAST

          def run(_errors)
            @snast = get_state(:snast_module, required: true)
            @cross_axes = get_state(:cross_axes, required: false) || {}
            @outer_axes = get_state(:outer_axes, required: false) || {}

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
            # A cross axis shares its parent's carrier; an outer axis is anchored
            # by its own source array (matched separately below). For the primary
            # prefix match, drop both kinds of synthetic axes.
            bound_axes = Array(wanted_axes).reject { |ax| @cross_axes.key?(ax) || @outer_axes.key?(ax) }

            # A purely-outer decl (axes are only outer tokens) anchors on the
            # source array of those outer axes.
            if bound_axes.empty?
              outer_src = Array(wanted_axes).map { |ax| @outer_axes[ax] }.compact
              return pick_anchor_for_source_axes(node, outer_src) unless outer_src.empty?

              return nil
            end

            wanted_axes = bound_axes
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

          # Find the input array whose axes match the given (real) source axes —
          # used to anchor a decl whose axes are purely outer tokens.
          def pick_anchor_for_source_axes(node, source_axes)
            found = nil
            walk = lambda do |x|
              case x
              when NAST::InputRef
                found ||= ir_fqn(x) if prefix?(source_axes, axes_of(x))
              when NAST::Ref
                walk.call(@snast.decls.fetch(x.name).body)
              when NAST::IndexRef
                found ||= x.input_fqn
              else
                x.children.each { |child| walk.call(child) }
              end
            end
            walk.call(node)
            found or raise "no anchor for outer source axes #{source_axes.inspect}"
          end

          def axes_of(n) = Array(n.meta[:stamp]&.dig(:axes))
          def prefix?(pre, full) = pre.each_with_index.all? { |tok, i| full[i] == tok }
          def ir_fqn(n) = n.instance_variable_get(:@fqn) || n.path.join(".")
        end
      end
    end
  end
end
