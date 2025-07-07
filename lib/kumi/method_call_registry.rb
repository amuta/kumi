# frozen_string_literal: true

module Kumi
  module MethodCallRegistry
    class UnknownMethodName < StandardError; end

    OPERATORS = %i[== > < >= <=].freeze

    Entry = Struct.new(:fn, :arity, :types)

    OPERATORS_PROCS = {
      :== => Entry.new(->(a, b) { a == b }, 2, %i[any any]),
      :> => Entry.new(->(a, b) { a >  b }, 2, %i[numeric numeric]),
      :< => Entry.new(->(a, b) { a <  b }, 2, %i[numeric numeric]),
      :>= => Entry.new(->(a, b) { a >= b }, 2, %i[numeric numeric]),
      :<= => Entry.new(->(a, b) { a <= b }, 2, %i[numeric numeric]),
      :add => Entry.new(->(a, b) { a + b }, 2, %i[numeric numeric])
    }.freeze

    @fn_proc = OPERATORS_PROCS.dup

    class << self
      def reset_registry!
        @fn_proc.clear
        @fn_proc.merge!(OPERATORS_PROCS)
      end

      def register_with(fn_name, &block)
        raise ArgumentError, "Operator #{fn_name.inspect} already registered" if @fn_proc.key?(fn_name)

        fn_lambda = block.is_a?(Proc) ? block : ->(*args) { yield(*args) }
        register(fn_name, fn_lambda, arity: fn_lambda.arity, types: [:any])
      end

      def register(fn_name, fn_lambda, arity:, types: [:any])
        raise ArgumentError, "Operator #{fn_name.inspect} already registered" if @fn_proc.key?(fn_name)

        @fn_proc[fn_name] = Entry.new(fn_lambda, arity, types)
      end

      def operator?(fn_name)
        return false unless fn_name.is_a?(Symbol)

        @fn_proc.key?(fn_name) && OPERATORS.include?(fn_name)
      end

      def freeze
        @fn_proc.freeze
        super
      end

      def fetch(fn_name)
        entry = @fn_proc[fn_name]
        confirm_support!(fn_name)

        entry.fn
      end

      def signature(fn_name)
        confirm_support!(fn_name)

        entry = @fn_proc[fn_name]

        { arity: entry.arity }
      end

      def supported?(fn_name)
        @fn_proc.key?(fn_name)
      end

      def all
        @fn_proc.keys
      end

      def confirm_support!(fn_name)
        raise UnknownMethodName, "Unknown method call with name: '#{fn_name.inspect}'" unless supported?(fn_name)
      end
    end
  end
end
