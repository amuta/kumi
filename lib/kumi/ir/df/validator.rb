# frozen_string_literal: true

module Kumi
  module IR
    module DF
      class Validator
        CANONICAL_OPS = %i[
          constant
          load_input
          load_field
          map
          select
          reduce
          decl_ref
          make_object
          array_build
          array_get
          array_len
          axis_index
          import_call
          axis_shift
          axis_broadcast
        ].freeze

        PRE_CANONICAL_OPS = (CANONICAL_OPS + %i[fold]).freeze

        FN_REF_OPS = %i[map reduce fold].freeze
        DEFAULT_TARGETS = %i[ruby javascript].freeze

        def self.validate!(df_module, allow_fold: false, registry: nil, targets: DEFAULT_TARGETS)
          new(df_module, allow_fold:, registry:, targets:).validate!
          df_module
        end

        def initialize(df_module, allow_fold: false, registry: nil, targets: DEFAULT_TARGETS)
          @df_module = df_module
          @allow_fold = allow_fold
          @registry = registry
          @targets = targets
        end

        def validate!
          df_module.each_function { |fn| validate_function(fn) }
        end

        private

        attr_reader :df_module

        def validate_function(function)
          function.blocks.each do |block|
            defs = {}
            block.instructions.each do |instr|
              defs[instr.result] = instr if instr.result
              validate_instruction(instr, defs)
              validate_fn_ref(function, instr)
            end
          end
        end

        # Registry coherence: every function reference must resolve to a
        # registered function with a kernel for every enabled target, so a
        # pass that mints an unregistered fn id fails here instead of as an
        # opaque crash at lowering or codegen time.
        def validate_fn_ref(function, instr)
          return unless @registry && FN_REF_OPS.include?(instr.opcode)

          fn = instr.attributes[:fn]
          return unless fn

          @targets.each do |target|
            @registry.kernel_for(fn, target: target)
          rescue StandardError => e
            raise ArgumentError,
                  "DFIR #{instr.opcode} #{instr.result.inspect} in function " \
                  "#{function.name.inspect} references #{fn.inspect}: #{e.message}"
          end
        end

        def validate_instruction(instr, defs)
          raise ArgumentError, "DFIR does not support opcode #{instr.opcode}" unless allowed_ops.include?(instr.opcode)

          case instr.opcode
          when :load_input
            chain = Array(instr.attributes[:chain])
            raise ArgumentError, "DFIR load_input with plan_ref must be root-only" if instr.attributes[:plan_ref] && !chain.empty?
          when :load_field
            source = defs[instr.inputs.first]
            if source && !prefix_axes?(Array(source.axes), Array(instr.axes))
              raise ArgumentError, "DFIR load_field must preserve or expand axes"
            end
          when :select
            raise ArgumentError, "DFIR select expects 3 inputs" unless instr.inputs.size == 3
          when :make_object
            keys = Array(instr.attributes[:keys])
            raise ArgumentError, "DFIR make_object inputs/keys mismatch" unless keys.size == instr.inputs.size
          when :axis_broadcast
            expected = Array(instr.attributes[:to_axes]).map(&:to_sym)
            raise ArgumentError, "DFIR axis_broadcast axes mismatch" unless Array(instr.axes) == expected
          when :reduce
            over_axes = Array(instr.attributes[:over_axes]).map(&:to_sym)
            raise ArgumentError, "DFIR reduce missing over_axes" if over_axes.empty?
          when :fold
            raise ArgumentError, "DFIR fold expects 1 input" unless instr.inputs.size == 1
          end
        end

        def allowed_ops
          @allow_fold ? PRE_CANONICAL_OPS : CANONICAL_OPS
        end

        def prefix_axes?(source_axes, field_axes)
          source_axes.each_with_index.all? { |axis, idx| field_axes[idx] == axis }
        end
      end
    end
  end
end
