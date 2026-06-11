# frozen_string_literal: true

module Kumi
  module IR
    module Passes
      class Base
        def run(graph:, context: {})
          raise NotImplementedError, "subclasses must implement #run"
        end
      end

      class Pipeline
        attr_reader :passes

        def initialize(passes = [])
          @passes = passes.dup
        end

        def add(pass)
          @passes << pass
          self
        end

        def run(graph:, context: {})
          @passes.reduce(graph) do |current, pass|
            pass.run(graph: current, context: context)
          end
        end
      end
    end
  end
end
