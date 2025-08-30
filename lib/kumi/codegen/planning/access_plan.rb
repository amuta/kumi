# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # AccessPlan is a thin index over analysis.inputs.
      # Responsibilities:
      #  - Normalize InputSpec instances
      #  - Answer: which axis tokens does a path CONSUME?
      #  - Provide deterministic method names for accessors (codegen)
      class AccessPlan
        attr_reader :inputs_by_path

        def initialize(input_specs)
          # key = path array joined by '/'
          @inputs_by_path = {}
          input_specs.each do |s|
            validate_input_spec(s)
            key = path_key(s.path)
            @inputs_by_path[key] = s
          end
        end

        # @return [InputSpec, nil]
        def for_path(path_array)
          @inputs_by_path[path_key(path_array)]
        end

        # @return [Array<Symbol>] axis tokens consumed by this path (in chain order)
        def consumes_axes(path_array)
          s = for_path(path_array) or return []
          (s.chain || []).filter_map do |st|
            ax = st["axis"] || st[:axis]
            kind = st["kind"] || st[:kind]
            kind.to_s.start_with?("array_") && ax ? ax.to_sym : nil
          end
        end

        # Deterministic helper names for codegen
        def scalar_accessor_name(path_array)
          "at_#{Array(path_array).map { |s| safe_ident(s) }.join('_')}"
        end

        def axis_len_method_name(axis, via_path_array)
          "len_#{safe_ident(axis)}__via_#{Array(via_path_array).map { |s| safe_ident(s) }.join('_')}"
        end

        # All inputs that carry a given axis (useful for diagnostics / asserts)
        def carriers_for_axis(axis_sym)
          @inputs_by_path.values.select do |s|
            (s.chain || []).any? do |st|
              (st["kind"] || st[:kind]).to_s.start_with?("array_") && (st["axis"] || st[:axis]).to_s == axis_sym.to_s
            end
          end
        end

        private

        def validate_input_spec(spec)
          # Validate that every array-consuming step in the chain declares an axis
          (spec.chain || []).each do |step|
            kind = step["kind"] || step[:kind]
            if kind && kind.to_s.start_with?("array_")
              axis = step["axis"] || step[:axis]
              unless axis
                raise "Untagged array step in path #{spec.path.join('.')}: step #{step.inspect}. " \
                      "Every array step must specify 'axis' token."
              end
            end
          end
        end

        def safe_ident(s)
          s.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
        end

        def path_key(path_array)
          Array(path_array).map(&:to_s).join("/")
        end
      end
    end
  end
end
