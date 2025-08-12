# frozen_string_literal: true

module Kumi
  module Core
    module IR
      Op = Struct.new(:tag, :attrs, :args, keyword_init: true) do
        def initialize(**args)
          super
          freeze
        end
      end
      Decl = Struct.new(:name, :kind, :shape, :ops, keyword_init: true) do
        def initialize(**args)
          super
          ops&.each(&:freeze)
          freeze
        end
      end
      Module = Struct.new(:inputs, :decls, keyword_init: true) do
        def initialize(**args)
          super
          decls&.each(&:freeze)
          freeze
        end
      end
    end

    module IR::Ops
      def self.Const(v)                      = IR::Op.new(tag: :const, attrs: { value: v }, args: [])
      def self.LoadInput(plan_id, scope: [], is_scalar: false, has_idx: false) = IR::Op.new(tag: :load_input, attrs: { plan_id: plan_id, scope: scope, is_scalar: is_scalar, has_idx: has_idx }, args: [])
      def self.Ref(name)                     = IR::Op.new(tag: :ref, attrs: { name: name }, args: [])
      def self.Map(fn, argc, *slots)         = IR::Op.new(tag: :map, attrs: { fn: fn, argc: argc }, args: slots)
      def self.Array(count, *slots)          = IR::Op.new(tag: :array, attrs: { count: count }, args: slots)
      def self.Switch(cases:, default:, slot:)= IR::Op.new(tag: :switch, attrs: { cases: cases, default: default }, args: [slot])
      def self.Store(name, slot)             = IR::Op.new(tag: :store, attrs: { name: name }, args: [slot])

      def self.Lift(to_scope, slot)          = IR::Op.new(tag: :lift, attrs: { to_scope: to_scope }, args: [slot])
      def self.Join(*slots)                  = IR::Op.new(tag: :join, attrs: {}, args: slots)
      
      # Up-sample `source` to the scope (and order) of `target` by index-prefix.
      # Policies: :error | :nil for missing; require_unique: true enforces 1:1 on prefix.
      def self.AlignTo(target_slot, source_slot, to_scope:, on_missing: :error, require_unique: true)
        scope_array = to_scope.is_a?(::Array) ? to_scope : [to_scope]
        IR::Op.new(
          tag: :align_to,
          attrs: { to_scope: scope_array, on_missing: on_missing, require_unique: require_unique },
          args: [target_slot, source_slot]
        )
      end

      def self.Reduce(fn, axis, result_scope, flatten, slot)
        IR::Op.new(tag: :reduce, attrs: { fn: fn, axis: axis, result_scope: result_scope, flatten: flatten }, args: [slot])
      end
    end
  end
end
