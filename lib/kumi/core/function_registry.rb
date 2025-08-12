# frozen_string_literal: true

module Kumi
  module Core
    # Internal function registry (single source of truth).
    module FunctionRegistry
      Entry = FunctionBuilder::Entry

      CORE_OPERATORS = %i[== > < >= <= != between?].freeze

      # Build core functions once
      CORE_FUNCTIONS = {}.tap do |registry|
        [
          ComparisonFunctions.definitions,
          MathFunctions.definitions,
          StringFunctions.definitions,
          LogicalFunctions.definitions,
          CollectionFunctions.definitions,
          ConditionalFunctions.definitions,
          TypeFunctions.definitions,
          StatFunctions.definitions
        ].each do |defs|
          defs.each do |name, entry|
            raise ArgumentError, "Duplicate core function: #{name}" if registry.key?(name)

            registry[name] = entry
          end
        end
      end.freeze

      @lock      = Mutex.new
      @functions = CORE_FUNCTIONS.transform_values(&:dup)
      @frozen    = false

      class FrozenError < RuntimeError; end

      class << self
        def auto_register(*mods)
          mods.each do |mod|
            mod.public_instance_methods(false).each do |m|
              next if function?(m)

              register(m) { |*args| mod.new.public_send(m, *args) }
            end
            mod.singleton_methods(false).each do |m|
              next if function?(m)

              fn = mod.method(m)
              register(m) { |*args| fn.call(*args) }
            end
          end
        end

        #
        # Lifecycle
        #
        def reset!
          @lock.synchronize do
            @functions = CORE_FUNCTIONS.transform_values(&:dup)
            @frozen    = false
          end
        end

        def freeze!
          @lock.synchronize do
            @functions.each_value(&:freeze)
            @functions.freeze
            @frozen = true
          end
        end

        def frozen?
          @frozen
        end

        #
        # Registration
        #
        # Unified entry point; used by both public and internal callers.
        def register(name, fn_or = nil, **meta, &block)
          fn = fn_or || block
          raise ArgumentError, "block or Proc required" unless fn.is_a?(Proc)

          defaults = {
            arity: fn.arity,
            param_types: [:any],
            return_type: :any,
            description: nil,
            param_modes: nil,
            reducer: false,
            structure_function: false
          }
          register_with_metadata(name, fn, **defaults, **meta)
        end

        # Back-compat explicit API
        def register_with_metadata(name, fn, arity:, param_types: [:any], return_type: :any,
                                   description: nil, param_modes: nil, reducer: false,
                                   structure_function: false)
          @lock.synchronize do
            raise FrozenError, "registry is frozen" if @frozen
            raise ArgumentError, "Function #{name.inspect} already registered" if @functions.key?(name)

            @functions[name] = Entry.new(
              fn: fn,
              arity: arity,
              param_types: param_types,
              return_type: return_type,
              description: description,
              param_modes: param_modes,
              reducer: reducer,
              structure_function: structure_function
            )
          end
        end

        #
        # Queries
        #
        def function?(name)
          @functions.key?(name)
        end
        alias supported? function?

        def operator?(name)
          name.is_a?(Symbol) && function?(name) && CORE_OPERATORS.include?(name)
        end

        def entry(name)
          @functions[name]
        end

        def fetch(name)
          ent = entry(name)
          raise Kumi::Errors::UnknownFunction, "Unknown function: #{name}" unless ent

          ent.fn
        end

        def signature(name)
          ent = entry(name) or raise Kumi::Errors::UnknownFunction, "Unknown function: #{name}"
          { arity: ent.arity, param_types: ent.param_types, return_type: ent.return_type, description: ent.description }
        end

        def reducer?(name)
          ent = entry(name)
          ent ? !!ent.reducer : false
        end

        def structure_function?(name)
          ent = entry(name)
          ent ? !!ent.structure_function : false
        end

        def all_functions
          @functions.keys
        end
        alias all all_functions

        def functions
          @functions.dup
        end

        # Introspection helpers
        def comparison_operators   = ComparisonFunctions.definitions.keys
        def math_operations        = MathFunctions.definitions.keys
        def string_operations      = StringFunctions.definitions.keys
        def logical_operations     = LogicalFunctions.definitions.keys
        def collection_operations  = CollectionFunctions.definitions.keys
        def conditional_operations = ConditionalFunctions.definitions.keys
        def type_operations        = TypeFunctions.definitions.keys
        def stat_operations        = StatFunctions.definitions.keys
      end
    end
  end
end
