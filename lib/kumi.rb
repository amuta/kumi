# frozen_string_literal: true

require "zeitwerk"
# require "pry" # COMMENT AFTER DEBUGGING

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/kumi-cli")
loader.ignore("#{__dir__}/kumi/text_parser")
loader.setup

module Kumi
  extend Schema
end
