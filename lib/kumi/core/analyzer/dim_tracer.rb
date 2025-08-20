# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module DimTracer
        module_function

        # Returns { root:, path:, dims:, depth: }
        # - root: :input, :decl, or :literal
        # - path: "users.name" (for inputs) or :decl_name (for decls)
        # - dims: array of symbolic indices, e.g. [:i], [:i, :j], or []
        # - depth: dims.size
        def trace(node, input_metadata = {}, input_name_index = {})
          case node
          when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference
            # Use metadata-driven approach (not broadcast prefixes)
            dims = input_name_index[node.name][:dimensional_scope]
            { root: :input, path: node.name, dims: dims, depth: dims.size }

          else
            # Literals and other nodes have no dimensions
            { root: :literal, path: nil, dims: [], depth: 0 }
          end
        end

        # Legacy method - deprecated, raises to prevent broadcast prefix usage
        def input_dims_for(path, broadcasts)
          raise "DEPRECATED: input_dims_for with broadcast prefixes is no longer supported. " \
                "Use input_dims_for_metadata with input_metadata instead. " \
                "This prevents hash navigation from being treated as dimensions."
        end
      end
    end
  end
end
