# frozen_string_literal: true

require_relative "../../naming/basename_normalizer"

module Kumi
  module Core
    module Analyzer
      module Passes
        # INPUT:  :declarations (ASTs), :node_index (built earlier)
        # OUTPUT: metadata annotations with fully qualified function names
        # GOAL:   resolve canonical basenames to registry qualified names (e.g. :add → "core.add")
        class CallNameNormalizePass < PassBase
          def run(errors)
            node_index = get_state(:node_index, required: true)

            node_index.each do |object_id, entry|
              next unless entry[:type] == 'CallExpression'
              node = entry[:node]
              before = node.fn_name
              canonical_name = Kumi::Core::Naming::BasenameNormalizer.normalize(before)

              # Resolve canonical name to qualified registry name
              qualified_name = resolve_to_qualified_name(canonical_name)
              
              # Annotate with both canonical and qualified names for downstream passes
              entry[:metadata][:canonical_name] = canonical_name
              entry[:metadata][:qualified_name] = qualified_name
              
              if before != canonical_name
                warn_deprecated(before, canonical_name) if ENV["WARN_DEPRECATED_FUNCS"]
              end
            end

            state
          end

          private

          def resolve_to_qualified_name(canonical_name)
            # Map canonical basenames to qualified registry names
            case canonical_name.to_sym
            # Core arithmetic and comparison functions
            when :add, :sub, :mul, :div, :mod, :pow
              "core.#{canonical_name}"
            when :eq, :ne, :lt, :le, :gt, :ge
              "core.#{canonical_name}"
            # Logical functions
            when :and, :or, :not
              "core.#{canonical_name}"
            # Collection/array functions
            when :get, :contains, :sum, :size, :length, :first, :last
              "array.#{canonical_name}"
            # String functions
            when :concat
              "string.#{canonical_name}"
            else
              # Default to core domain for unknown functions
              "core.#{canonical_name}"
            end
          end

          def warn_deprecated(before, after)
            $stderr.puts "[kumi] deprecated function name #{before.inspect} → #{after.inspect}"
          end
        end
      end
    end
  end
end