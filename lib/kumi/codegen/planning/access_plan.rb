# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # AccessPlan provides an indexed view over the `analysis.inputs` array,
      # facilitating the calculation of navigation paths between different
      # dimensional contexts (axes).
      class AccessPlan
        attr_reader :inputs_by_fqn
        attr_reader :specs_by_axes

        def initialize(input_specs)
          @inputs_by_fqn = input_specs.each_with_object({}) do |spec, memo|
            memo[spec['path_fqn']] = spec
          end.freeze

          @specs_by_axes = input_specs.each_with_object({}) do |spec, memo|
            axes = spec['axes']
            memo[axes] ||= spec
          end.freeze
        end

        def spec_for_path(path)
          key = path.is_a?(Array) ? path.join('.') : path
          @inputs_by_fqn[key]
        end

        def steps_for(from_axes, to_axes)
          return { exits: 0, entries: [] } if from_axes == to_axes

          common_len = 0
          while common_len < from_axes.size && common_len < to_axes.size && from_axes[common_len] == to_axes[common_len]
            common_len += 1
          end

          exits = from_axes.size - common_len
          target_spec = @specs_by_axes[to_axes]
          raise "Cannot find a navigation plan for target axes: #{to_axes.inspect}" unless target_spec

          # --- Start of corrected logic ---
          all_steps = target_spec['navigation_steps']
          loop_indices = all_steps.each_index.select { |i| all_steps[i]['kind'] == 'array_loop' }

          start_index = common_len.zero? ? 0 : loop_indices[common_len - 1] + 1
          end_index = loop_indices[to_axes.size - 1]
          
          entries = all_steps.slice(start_index, end_index - start_index + 1)
          # --- End of corrected logic ---

          { exits: exits, entries: entries }
        end
      end
    end
  end
end