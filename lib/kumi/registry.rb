module Kumi
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

      def register(name, &block)
        @lock.synchronize do
          raise FrozenError, "registry is frozen" if @frozen

          super
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
