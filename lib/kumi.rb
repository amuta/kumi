# frozen_string_literal: true

require "zeitwerk"
# require "pry" # COMMENT AFTER DEBUGGING

loader = Zeitwerk::Loader.for_gem
loader.setup

module Kumi
  extend Schema
end
