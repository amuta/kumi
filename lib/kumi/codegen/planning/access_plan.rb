# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # AccessPlan is a thin index over analysis.inputs.
      # Responsibilities:
      #  - Normalize InputSpec instances
      #  - Answer: which axis tokens does a path CONSUME?
      #  - Provide deterministic method names for accessors (codegen)
      class AccessPlan
        attr_reader :inputs_by_path

        def initialize(input_specs)
          # key = path array joined by '/'
          @inputs_by_path = {}
          input_specs.each do |s|
            validate_input_spec(s)
            key = path_key(s.path)
            @inputs_by_path[key] = s
          end
        end

        # @return [InputSpec, nil]
        def for_path(path_array)
          @inputs_by_path[path_key(path_array)]
        end

        # @return [Array<Symbol>] axis tokens from axis_loops
        def consumes_axes(path_array)
          s = for_path(path_array) or return []
          puts "[DEBUG] AccessPlan.consumes_axes: path=#{path_array.inspect}, axis_loops=#{s.axis_loops.inspect}"
          result = s.axis_loops.map { |loop| (loop[:axis] || loop["axis"]).to_s.to_sym }
          puts "[DEBUG] AccessPlan.consumes_axes: result=#{result.inspect}"
          result
        end

        # Deterministic helper names for codegen
        def scalar_accessor_name(path_array)
          "at_#{Array(path_array).map { |s| safe_ident(s) }.join('_')}"
        end

        private

        def validate_input_spec(spec)
          # Validate that axis_loops contain valid axis information
          spec.axis_loops.each do |loop|
            unless loop[:axis]
              raise "Missing axis in loop for path #{spec.path.join('.')}: #{loop.inspect}"
            end
          end
        end

        def safe_ident(s)
          s.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
        end

        def path_key(path_array)
          Array(path_array).map(&:to_s).join("/")
        end
      end
    end
  end
end
