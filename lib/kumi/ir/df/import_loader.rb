# frozen_string_literal: true

module Kumi
  module IR
    module DF
      class ImportLoader
        def initialize(imported_schemas, pipeline: nil)
          @imported_schemas = (imported_schemas || {}).transform_keys(&:to_sym)
          @cache = {}
          @pipeline = pipeline
        end

        def function(fn_name)
          graph = graph_for(fn_name.to_sym)
          return nil unless graph

          graph.functions[fn_name.to_sym]
        end

        private

        attr_reader :imported_schemas, :cache, :pipeline

        def graph_for(fn_name)
          cache[fn_name] ||= build_graph(fn_name)
        end

        def build_graph(fn_name)
          meta = imported_schemas[fn_name]
          return nil unless meta

          analyzed_state = meta[:analyzed_state] || {}
          snast = analyzed_state[:snast_module]
          registry = analyzed_state[:registry]
          input_table = analyzed_state[:input_table]
          return nil unless snast && registry && input_table

          graph = Kumi::IR::DF::Lower.new(
            snast_module: snast,
            registry: registry,
            input_table: input_table,
            input_metadata: analyzed_state[:input_metadata] || {}
          ).call

          runner = pipeline || default_pipeline
          runner.run(graph: graph, context: { registry: registry, input_table: input_table })
        end

        def default_pipeline
          passes = [
            Kumi::IR::DF::Passes::DeclInlining.new,
            Kumi::IR::DF::Passes::LoadDedup.new,
            Kumi::IR::DF::Passes::BroadcastSimplify.new,
            Kumi::IR::DF::Passes::CSE.new,
            Kumi::IR::DF::Passes::StencilCSE.new
          ]
          Kumi::IR::Passes::Pipeline.new(passes)
        end
      end
    end
  end
end
