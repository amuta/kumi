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
          input_metadata = state[:input_metadata] || {}
          decl_shapes = state[:decl_shapes] || {}
          
          case node
          when Kumi::Syntax::DeclarationReference
            # Pass-order safety: before Pass 18, decl_shapes may not exist
            shape = decl_shapes[node.name]
            dims = shape&.dig(:scope) || []
            { root: :decl, path: node.name, dims: dims, depth: dims.size }
            
          when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference
            # Use metadata-driven approach (not broadcast prefixes)
            path_array = node.respond_to?(:path) ? node.path : []
            dims = input_dims_for_metadata(path_array, input_metadata)
            path_string = node.respond_to?(:path_string) ? node.path_string : nil
            { root: :input, path: path_string, dims: dims, depth: dims.size }
            
          else
            # Literals and other nodes have no dimensions
            { root: :literal, path: nil, dims: [], depth: 0 }
          end
        end

        # Metadata-driven dimension calculation (replaces broadcast prefix heuristics)
        def input_dims_for_metadata(path_array, input_metadata)
          return [] if path_array.nil? || path_array.empty?
          
          dims = []
          meta = input_metadata
          
          path_array.each do |seg|
            field = meta[seg] || meta[seg.to_sym] || meta[seg.to_s]
            unless field
              raise "Path segment '#{seg}' not found in input metadata at #{path_array.inspect}"
            end
            
            # Only array boundaries create dimensions
            dims << seg.to_sym if field[:type] == :array
            
            meta = field[:children] || {}
          end
          
          dims
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