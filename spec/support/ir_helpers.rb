# frozen_string_literal: true

module IRHelpers
  def snast_factory = Kumi::IR::Testing::SnastFactory
  def ir_types = Kumi::Core::Types
  def df_ops = Kumi::IR::DF::Ops

  def build_snast_module(name, axes:, dtype:, **opts, &body)
    raise ArgumentError, "block required" unless body

    snast_factory.build do |b|
      b.declaration(name, axes:, dtype:, **opts) { body.call }
    end
  end

  def df_graph_with_function(snast_module, name:)
    graph = Kumi::IR::DF::Graph.from_snast(snast_module)
    function = Kumi::IR::DF::Function.new(name:, blocks: [Kumi::IR::Base::Block.new(name: :entry)])
    graph.add_function(function)
    [graph, function]
  end

  def df_builder(graph:, function:)
    Kumi::IR::DF::Builder.new(ir_module: graph, function:)
  end

  def df_block(name: :entry, instructions: [])
    Kumi::IR::Base::Block.new(name:, instructions:)
  end

  def df_function(name:, blocks: [df_block])
    Kumi::IR::DF::Function.new(name:, blocks:)
  end
end

RSpec.configure do |config|
  config.include IRHelpers
end
