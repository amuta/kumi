# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      # Resolves dimensional execution context for all declarations based on their dependencies
      # Determines where each declaration should execute (depth/dimension) 
      class DimensionalResolver
        # Analyze all declarations' dependencies to determine their execution contexts
        #
        # @param dependency_graph [Hash] Hash of declaration_name => [DependencyEdge, ...]
        # @param input_metadata [Hash] Input metadata from InputCollector with depth information
        # @return [Hash] { declaration_name: { dimension: [path], depth: number }, ... }
        def self.analyze_all(dependency_graph, input_metadata)
          dependency_graph.transform_values { |deps| analyze_declaration(deps, input_metadata) }
        end

        # Analyze a single declaration's dependencies to determine its execution context
        #
        # @param dependencies [Array<DependencyEdge>] List of DependencyEdge objects from DependencyResolver
        # @param input_metadata [Hash] Input metadata from InputCollector with depth information
        # @return [Hash] { dimension: [path], depth: number }
        def self.analyze_declaration(dependencies, input_metadata)
          return { dimension: [], depth: 0 } if dependencies.empty?

          input_paths = extract_input_paths_from_edges(dependencies, input_metadata)
          deepest_path = find_deepest_path(input_paths)
          
          {
            dimension: deepest_path[:path],
            depth: deepest_path[:depth]
          }
        end

        private

        # Extract input field paths from DependencyEdge objects
        # Filters out non-input dependencies (only processes :key type edges)
        def self.extract_input_paths_from_edges(dependency_edges, input_metadata)
          dependency_edges
            .select { |edge| edge.type == :key }
            .filter_map do |edge|
              field_key = input_metadata.key?(edge.to) ? edge.to : edge.to.to_sym
              build_path_info(field_key, input_metadata) if input_metadata.key?(field_key)
            end
        end

        # Build path information for a field
        def self.build_path_info(field_key, input_metadata)
          meta = input_metadata[field_key]
          path = build_full_path(field_key, meta)
          
          {
            path: path,
            depth: path.size
          }
        end

        # Build the full path from field metadata
        def self.build_full_path(field_name, metadata)
          return [] unless metadata[:type] == :array
          
          path = [field_name]
          current = metadata
          
          while current[:children]&.any?
            array_child = current[:children].find { |_k, v| v[:type] == :array }
            break unless array_child
            
            child_key, child_meta = array_child
            path << child_key
            current = child_meta
          end
          
          path
        end

        # Find the deepest path among all input paths
        def self.find_deepest_path(paths)
          paths.max_by { |path_info| path_info[:depth] } || { path: [], depth: 0 }
        end

        # Alternative implementation that works with actual AST paths
        def self.analyze_from_paths(input_paths, input_metadata)
          path_depths = input_paths.map do |path|
            { path: path, depth: path.size }
          end
          
          deepest = path_depths.max_by { |pd| pd[:depth] } || { path: [], depth: 0 }
          
          {
            dimension: deepest[:path],
            depth: deepest[:depth]
          }
        end
      end
    end
  end
end