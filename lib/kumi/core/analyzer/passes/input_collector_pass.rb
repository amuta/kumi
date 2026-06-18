# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class InputCollectorPass < PassBase
          writes :input_metadata

          Node = Struct.new(:type, :domain, :container, :children, :access_mode, :child_steps, :define_index, keyword_init: true) do
            def as_json(*)
              {
                type: type,
                domain: domain,
                container: container,
                children: children&.transform_values(&:as_json),
                access_mode: access_mode,
                child_steps: child_steps,
                define_index: define_index
              }
            end

            def to_json(*args)
              as_json.to_json(*args)
            end
          end

          def run(errors)
            meta = {}
            schema.inputs.each { |decl| meta[decl.name] = build_node(decl) }

            # validate shape first (nice error messages with full path)
            validate_arity!(meta, errors, path: [])

            # then annotate navigation info
            annotate_children!(meta, errors)
            state.with(:input_metadata, meta.freeze)
          end

          private

          def build_node(decl)
            container = kind_from_type(decl.type)
            kids = nil
            if decl.children&.any?
              kids = {}
              decl.children.each { |ch| kids[ch.name] = build_node(ch) }
            end

            Node.new(type: decl.type, domain: decl.domain, container: container, children: kids, child_steps: {}, define_index: decl.index)
          end

          def validate_arity!(meta, errors, path:)
            meta.each do |name, node|
              cur_path = (path + [name]).join(".")

              if node.container == :array
                chsz = (node.children || {}).size
                report_error(errors, array_arity_error(cur_path, chsz)) unless chsz == 1
                node.access_mode = :element
              end

              validate_arity!(node.children || {}, errors, path: path + [name])
            end
          end

          # An array declares exactly one child: the named element it maps over.
          # Kumi maps by default, so the element MUST be named — that name is the
          # per-element binding you reference in the schema body. The two failure
          # modes (no element, several elements) each get targeted guidance.
          def array_arity_error(path, child_count)
            base = "Array input '#{path}' must declare exactly one element (got #{child_count}). " \
                   "Kumi maps over arrays by default, so the element needs a name to map onto."
            if child_count.zero?
              base + " Name the element with a single child, e.g.\n" \
                     "  array :#{path.split('.').last} do\n" \
                     "    float :value          # scalar element, referenced as input.#{path.split('.').last}.value\n" \
                     "  end\n" \
                     "Use a `hash` child instead when each element has several fields, " \
                     "or a nested `array` child for an array of arrays."
            else
              base + " Wrap multiple fields in a single `hash` element rather than declaring them side by side, e.g.\n" \
                     "  array :#{path.split('.').last}, index: :i do\n" \
                     "    hash :i do\n" \
                     "      float :a\n" \
                     "      float :b\n" \
                     "    end\n" \
                     "  end"
            end
          end

          # Annotate per-child hops (no arity checks here to avoid duplicates)
          def annotate_children!(meta, _errors, indent: 0)
            meta.each do |name, node|
              prefix = "  " * indent
              debug "#{prefix}[#{name}] (#{node.container})"
              node.child_steps = {}
              (node.children || {}).each do |cname, child|
                steps =
                  case node.container
                  when :hash, :object
                    if child.container == :array
                      [
                        { kind: :property_access, key: cname.to_s },
                        { kind: :array_loop,      axis: cname.to_s }
                      ]
                    else
                      [{ kind: :property_access, key: cname.to_s }]
                    end
                  when :array
                    if child.container == :array
                      [
                        { kind: :element_access },
                        { kind: :array_loop, axis: cname.to_s }
                      ]
                    else
                      [{ kind: :element_access }]
                    end
                  else
                    raise Kumi::Core::Errors::CompilerBug, "unknown parent container #{node.container.inspect}"
                  end

                step_str = steps.map { |s| s[:kind] == :array_loop ? "loop(#{s[:axis]})" : s[:kind].to_s.split("_").first }.join(" → ")
                debug "#{prefix}  └─ #{cname}: #{step_str}"
                node.child_steps[cname.to_sym] = steps
              end

              annotate_children!(node.children || {}, _errors, indent: indent + 1)
            end
          end

          def kind_from_type(t)
            # Handle both symbols (legacy) and Type objects (new)
            case t
            when Kumi::Core::Types::ArrayType
              :array
            when Kumi::Core::Types::TupleType
              :array # Tuples behave like arrays for input access
            when :array, Kumi::Core::Types::ScalarType
              # Check if it's a hash scalar or :hash symbol
              if t.is_a?(Kumi::Core::Types::ScalarType) && t.kind == :hash
                :hash
              elsif t == :hash
                :hash
              elsif t == :array
                :array
              else
                :scalar
              end
            when :hash
              :hash
            else
              :scalar
            end
          end
        end
      end
    end
  end
end
