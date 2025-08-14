# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Emits per-node metadata:
        #   :type, :domain
        #   :container     => :scalar | :field | :array
        #   :access_mode   => :field | :element          # how THIS node is read once reached
        #   :enter_via     => :hash | :array           # how we HOP from parent to THIS node
        #   :consume_alias => true|false               # inline array hop (alias is not a hash key)
        #   :children      => { name => node_meta }    # optional
        #
        # Invariants:
        # - Any nested array (child depth ≥ 1) must declare its element (i.e., have children).
        # - Depth-0 inputs always: enter_via :hash, consume_alias false, access_mode :field.
        class InputCollector < PassBase
          def run(errors)
            input_meta = {}

            schema.inputs.each do |decl|
              name = decl.name
              input_meta[name] = collect_field_metadata(decl, errors, depth: 0, name: name)
            end

            input_meta.each_value(&:deep_freeze!)
            state.with(:input_metadata, input_meta.freeze)
          end

          private

          # ---------- builders ----------

          def collect_field_metadata(decl, errors, depth:, name:)
            children = nil
            if decl.children&.any?
              children = {}
              decl.children.each do |child|
                children[child.name] = collect_field_metadata(child, errors, depth: depth + 1, name: child.name)
              end
            end

            access_mode = decl.access_mode || :field

            meta = Structs::InputMeta.new(
              type: decl.type,
              domain: decl.domain,
              container: kind_from_type(decl.type),
              access_mode: access_mode,
              enter_via: :hash,
              consume_alias: false,
              children: children
            )
            stamp_edges_from!(meta, errors, parent_depth: depth)
            validate_access_modes!(meta, errors, parent_depth: depth)
            meta
          end

          # ---------- edge stamping + validation ----------
          #
          # Sets child[:enter_via], child[:consume_alias], child[:access_mode] defaults,
          # and validates nested arrays declare their element.
          #
          # Rules:
          # - Common: any ARRAY child at child-depth ≥ 1 must have children (no bare nested array).
          # - Parent :object → any child:
          #     child.enter_via = :hash; child.consume_alias = false; child.access_mode ||= :field
          # - Parent :array:
          #     * If exactly one child:
          #         - child.container ∈ {:scalar, :array} → via :array, consume_alias true, access_mode :element
          #         - child.container == :field         → via :hash,  consume_alias false, access_mode :field
          #     * Else (element object): every child → via :hash, consume_alias false, access_mode :field
          def stamp_edges_from!(parent_meta, errors, parent_depth:)
            kids = parent_meta.children || {}
            return if kids.empty?

            # Validate nested arrays anywhere below root
            kids.each do |kname, child|
              next unless child.container == :array

              if !child.children || child.children.empty?
                report_error(errors, "Nested array at :#{kname} must declare its element", location: nil)
              end
            end

            case parent_meta.container
            when :object, :hash
              kids.each_value do |child|
                child.enter_via = :hash
                child.consume_alias = false
                child.access_mode = :field
              end

            when :array
              # Array parents MUST explicitly declare their access mode
              access_mode = parent_meta.access_mode
              raise "Array must explicitly declare access_mode (:field or :element)" unless access_mode

              case access_mode
              when :field
                # Array of objects: all children are fields accessed via hash
                kids.each_value do |child|
                  child.enter_via = :hash
                  child.consume_alias = false
                  child.access_mode = :field
                end

              when :element
                _name, only = kids.first
                only.enter_via = :array
                only.consume_alias = true
                only.access_mode = :element

              else
                raise "Invalid access_mode :#{access_mode} for array (must be :field or :element)"
              end
            end
          end

          # Enforce access_mode semantics are only used in valid contexts.
          def validate_access_modes!(parent_meta, errors, parent_depth:)
            kids = parent_meta.children || {}
            return if kids.empty?

            kids.each do |kname, child|
              mode = child.access_mode
              next unless mode

              unless %i[field element].include?(mode)
                report_error(errors, "Invalid access_mode for :#{kname}: #{mode.inspect}", location: nil)
                next
              end

              if mode == :element
                if parent_meta.container == :array
                  single = (kids.size == 1)
                  unless single && %i[scalar array].include?(child.container)
                    report_error(errors, "access_mode :element only valid for single scalar/array element (at :#{kname})", location: nil)
                  end
                else
                  report_error(errors, "access_mode :element only valid under array parent (at :#{kname})", location: nil)
                end
              end
            end
          end

          def kind_from_type(t)
            return :array if t == :array
            return :hash if t == :hash
            return :object if t == :field

            :scalar
          end
        end
      end
    end
  end
end
