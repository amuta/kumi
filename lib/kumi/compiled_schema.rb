# frozen_string_literal: true

module Kumi
  class CompiledSchema
    attr_reader :bindings

    def initialize(bindings)
      @bindings = bindings.freeze
    end

    def evaluate(data, *keys)
      validate_context(data)

      target_keys = keys.empty? ? @bindings.keys : validate_keys(keys)

      target_keys.each_with_object({}) do |key, result|
        result[key] = execute_binding(key, data)
      end
    end

    def evaluate_binding(key, data)
      validate_context(data)
      validate_binding_exists(key)
      execute_binding(key, data)
    end

    def traits(data)
      evaluate_by_type(data, :trait)
    end

    def attributes(data)
      evaluate_by_type(data, :attr)
    end

    private

    def validate_context(data)
      return if data.is_a?(Hash) || hash_like?(data)

      raise Kumi::Errors::RuntimeError,
            "Data context should be Hash-like (respond to :key? and :[])"
    end

    def hash_like?(obj)
      obj.respond_to?(:key?) && obj.respond_to?(:[])
    end

    def validate_keys(keys)
      unknown_keys = keys - @bindings.keys
      return keys if unknown_keys.empty?

      raise Kumi::Errors::RuntimeError, "No binding named #{unknown_keys.first}"
    end

    def validate_binding_exists(key)
      return if @bindings.key?(key)

      raise Kumi::Errors::RuntimeError, "No binding named #{key}"
    end

    def execute_binding(key, data)
      _type, proc = @bindings[key]
      proc.call(data)
    end

    def evaluate_by_type(data, target_type)
      validate_context(data)

      filtered_keys = filter_keys_by_type(target_type)

      filtered_keys.each_with_object({}) do |key, result|
        result[key] = execute_binding(key, data)
      end
    end

    def filter_keys_by_type(target_type)
      @bindings.filter_map { |key, (type, _proc)| key if type == target_type }
    end
  end
end
