module Kumi
  # Public interface for registering custom functions in Kumi schemas
  #
  # Usage:
  #   Kumi::Registry.register(:my_function) do |x|
  #     x * 2
  #   end
  module Registry
    extend Core::FunctionRegistry
    Entry = Core::FunctionRegistry::FunctionBuilder::Entry

    @functions = Core::FunctionRegistry::CORE_FUNCTIONS.transform_values(&:dup)
    @frozen    = false
    @lock      = Mutex.new

    class FrozenError < RuntimeError; end

    class << self
      def reset!
        @lock.synchronize do
          @functions = Core::FunctionRegistry::CORE_FUNCTIONS.transform_values(&:dup)
          @frozen    = false
        end
      end

      # Register a custom function with the Kumi function registry
      #
      # Example:
      #   Kumi::Registry.register(:double) do |x|
      #     x * 2
      #   end
      #
      #   # Use in schema:
      #   value :doubled, fn(:double, input.number)
      def register(name, &block)
        @lock.synchronize do
          raise FrozenError, "registry is frozen" if @frozen
          raise ArgumentError, "Function #{name.inspect} already registered" if @functions.key?(name)

          fn_lambda = block.is_a?(Proc) ? block : ->(*args) { yield(*args) }
          @functions[name] = Entry.new(
            fn: fn_lambda,
            arity: fn_lambda.arity,
            param_types: [:any],
            return_type: :any,
            description: nil,
            inverse: nil,
            reducer: false
          )
        end
      end

      # Register a custom function with detailed metadata for type and domain validation
      #
      # Example:
      #   Kumi::Registry.register_with_metadata(
      #     :add_tax,
      #     ->(amount, rate) { amount * (1 + rate) },
      #     arity: 2,
      #     param_types: [:float, :float],
      #     return_type: :float,
      #     description: "Adds tax to an amount",
      #   )
      #
      #   # Use in schema:
      #   value :total, fn(:add_tax, input.price, input.tax_rate)
      def register_with_metadata(name, fn_lambda, arity:, param_types: [:any], return_type: :any, description: nil, inverse: nil,
                                 reducer: false)
        @lock.synchronize do
          raise FrozenError, "registry is frozen" if @frozen
          raise ArgumentError, "Function #{name.inspect} already registered" if @functions.key?(name)

          @functions[name] = Entry.new(
            fn: fn_lambda,
            arity: arity,
            param_types: param_types,
            return_type: return_type,
            description: description,
            inverse: inverse,
            reducer: reducer
          )
        end
      end

      def freeze!
        @lock.synchronize do
          @functions.each_value(&:freeze)
          @functions.freeze
          @frozen = true
        end
      end
    end
  end
end
