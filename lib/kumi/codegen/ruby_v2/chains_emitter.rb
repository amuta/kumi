# frozen_string_literal: true

require_relative "name_mangler"

module Kumi
  module Codegen
    module RubyV2
      module ChainsEmitter
        module_function

        def render(inputs:)
          src = +""
          map = {}

          Array(inputs).each do |inp|
            name = inp.fetch("name")

            # Use the chain from the input spec (already computed by access planner)
            steps = Array(inp.fetch("chain"))

            const = NameMangler.chain_const_for(name)
            map[name] = const
            src << "#{const} = #{steps.inspect}.freeze\n"
          end

          [src, map]
        end
      end
    end
  end
end
