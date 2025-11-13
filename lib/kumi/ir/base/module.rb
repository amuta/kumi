# frozen_string_literal: true

module Kumi
  module IR
    module Base
      class Module
        attr_reader :name, :functions

        def initialize(name:, functions: [])
          @name = name.to_sym
          @functions = {}
          functions.each { |fn| add_function(fn) }
        end

        def add_function(fn)
          raise ArgumentError, "function required" unless fn.is_a?(Function)
          @functions[fn.name] = fn
        end

        def fetch_function(name, &blk)
          @functions.fetch(name.to_sym, &blk)
        end

        def each_function(&blk)
          @functions.values.each(&blk)
        end

        def to_h
          {
            name:,
            functions: @functions.values.map(&:to_h)
          }
        end
      end
    end
  end
end
