# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Pipeline do
  it "returns graph unchanged when no passes are registered" do
    graph = Kumi::IR::DF::Graph.new(name: :demo)
    optimized = described_class.run(graph:, context: {})
    expect(optimized).to equal(graph)
  end
end
