# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:dependency_graph, :leaf_map, :topo_order, keyword_init: true)

    module_function

    DEFAULT_PASSES = [
      Passes::NameIndexer,
      Passes::TypeValidator,
      Passes::CycleDetector,
      Passes::Toposorter
    ].freeze

    def analyze!(schema, passes: DEFAULT_PASSES, **opts)
      analysis_state = { opts: opts } # renamed from :summary
      errors = []

      passes.each { |klass| klass.new(schema, analysis_state).run(errors) }

      raise Errors::SemanticError, format(errors) unless errors.empty?

      Result.new(
        dependency_graph: analysis_state[:dependency_graph].freeze,
        leaf_map: analysis_state[:leaf_map].freeze,
        topo_order: analysis_state[:topo_order].freeze
      )
    end

    def format(errs) = errs.map { |loc, msg| "at #{loc || '?'}: #{msg}" }.join("\n")
  end
end
