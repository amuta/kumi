# frozen_string_literal: true

require_relative "passes/support/instruction_cloner"

module Kumi
  module IR
    module DF
      class ImportInliner
        def initialize(axis_map:, extra_axes: [])
          @axis_map = normalize_axis_map(axis_map)
          @extra_axes = Array(extra_axes).map { |axis| axis&.to_sym }.compact
        end

        def remap_function(function)
          new_blocks = function.blocks.map { remap_block(_1) }
          Kumi::IR::DF::Function.new(
            name: function.name,
            parameters: function.parameters,
            blocks: new_blocks,
            return_stamp: function.return_stamp
          )
        end

        private

        attr_reader :axis_map, :extra_axes

        def normalize_axis_map(map)
          map.each_with_object({}) do |(from, to), memo|
            memo[from.to_sym] = to.to_sym
          end
        end

        def remap_block(block)
          new_instructions = block.instructions.map { remap_instruction(_1) }
          Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
        end

        def remap_instruction(instr)
          remapped_axes = remap_axes(instr.axes)
          merged_axes = merge_axes(remapped_axes)
          new_metadata = (instr.metadata || {}).merge(
            axes: merged_axes,
            dtype: instr.dtype
          )
          new_attrs = remap_attributes(instr)
          Passes::Support::InstructionCloner.clone(instr, instr.inputs, attributes: new_attrs, metadata: new_metadata)
        end

        def remap_axes(list)
          return list unless list.respond_to?(:map)

          list.map { |axis| remap_axis(axis) }
        end

        def merge_axes(remapped_axes)
          current = remapped_axes || []
          (extra_axes + current).each_with_object([]) do |axis, acc|
            next if acc.include?(axis)

            acc << axis
          end
        end

        def remap_axis(axis)
          return axis unless axis

          axis_map.fetch(axis.to_sym, axis.to_sym)
        end

        def remap_attributes(instr)
          attrs = instr.attributes ? instr.attributes.dup : {}

          if attrs.key?(:axis) && attrs[:axis]
            attrs[:axis] = remap_axis(attrs[:axis])
          end

          %i[from_axes to_axes over_axes].each do |key|
            next unless attrs[key]

            attrs[key] = remap_axes(attrs[key])
          end

          attrs
        end
      end
    end
  end
end
