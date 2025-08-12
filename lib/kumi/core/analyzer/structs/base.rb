# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Structs
        # Base class for analyzer structs with validation and contract enforcement
        class Base
          class ValidationError < StandardError; end

          def initialize(**attrs)
            @data = {}
            attrs.each do |key, value|
              self[key] = value
            end
            validate!
            freeze
          end

          def [](key)
            @data.fetch(key.to_sym) do
              raise ArgumentError, "Missing required field '#{key}' in #{self.class.name}. Available: #{@data.keys.inspect}"
            end
          end

          def []=(key, value)
            @data[key.to_sym] = value
          end

          def key?(key)
            @data.key?(key.to_sym)
          end

          def fetch(key, default = nil)
            if default.nil?
              @data.fetch(key.to_sym)
            else
              @data.fetch(key.to_sym, default)
            end
          end

          def keys
            @data.keys
          end

          def to_h
            @data.dup
          end

          def inspect
            "#{self.class.name}(#{@data.inspect})"
          end

          private
        end
      end
    end
  end
end