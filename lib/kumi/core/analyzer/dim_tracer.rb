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
        def trace(node, state)
          broadcasts  = state[:broadcasts] || {}
          decl_shapes = state[:decl_shapes] || {}
          case node
          when Kumi::Syntax::DeclarationReference
            shape = decl_shapes[node.name] || {}
            dims  = shape[:scope] || []
            { root: :decl, path: node.name, dims: dims, depth: dims.size }
          when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference
            path = node.respond_to?(:path_string) ? node.path_string : nil
            dims = input_dims_for(path, broadcasts)
            { root: :input, path: path, dims: dims, depth: dims.size }
          else
            { root: :literal, path: nil, dims: [], depth: 0 }
          end
        end

        def input_dims_for(path, broadcasts)
          return [] unless path
          
          # Handle new string prefix format (preferred)
          if broadcasts[:nested_prefixes] && broadcasts[:array_prefixes]
            np = broadcasts[:nested_prefixes]
            ap = broadcasts[:array_prefixes]
            if np.any? { |p| path.start_with?(p) } || ap.any? { |p| path.start_with?(p) }
              return [:i]
            else
              return []
            end
          end
          
          # Handle legacy hash format for backward compatibility
          np = broadcasts[:nested_paths] || {}
          af = broadcasts[:array_fields] || {}
          
          # Convert hash keys to string prefixes if needed
          nested_prefixes = np.is_a?(Hash) ? np.keys.map { |k| k.join(".") } : Array(np)
          array_prefixes = af.is_a?(Hash) ? af.keys.map(&:to_s) : Array(af)
          
          if nested_prefixes.any? { |p| path.start_with?(p) } || array_prefixes.any? { |p| path.start_with?(p) }
            [:i]
          else
            []
          end
        end
      end
    end
  end
end