# frozen_string_literal: true

require "zeitwerk"
# require "pry" # COMMENT AFTER DEBUGGING

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/kumi-cli")
loader.setup

module Kumi
  extend Schema

  def self.inspector_from_schema
    Inspector.new(@__syntax_tree__, @__analyzer_result__, @__compiled_schema__)
  end

  def self.reset!
    @__syntax_tree__ = nil
    @__analyzer_result__ = nil
    @__compiled_schema__ = nil
    @__schema_metadata__ = nil
  end

  # Reset on require to avoid state leakage in tests
  reset!
end
