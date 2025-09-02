# frozen_string_literal: true

require_relative "name_mangler"

module Kumi
  module Codegen
    module RubyV2
      module ChainsEmitter
        module_function

        def render(plan_module_spec_inputs:)
          src = +""
          map = {}

          Array(plan_module_spec_inputs).each do |inp|
            path = Array(inp.fetch("path")).map(&:to_s)
            axes = Array(inp.fetch("axes")).map(&:to_s)
            steps = []
            path.each_with_index do |seg, i|
              if i < path.length - 1
                axis = axes[i] or raise "Missing axis for path segment '#{seg}' at index #{i} in input #{name}"
                steps << {"kind"=>"array_field","key"=>seg,"axis"=>axis}
              else
                steps << {"kind"=>"field_leaf","key"=>seg}
              end
            end

            name  = path.join(".")
            const = NameMangler.chain_const_for(name)
            map[name] = const
            src << "#{const} = JSON.parse(#{JSON.generate(JSON.generate(steps))}).freeze\n"
          end

          [src, map]
        end
      end
    end
  end
end