# frozen_string_literal: true

require "zeitwerk"
# require "pry" # COMMENT AFTER DEBUGGING

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/kumi-cli")
loader.inflector.inflect(
  "lower_to_ir_pass" => "LowerToIRPass",
  "lower_to_ir" => "LowerToIR",
  "vm" => "VM",
  "ir" => "IR",
  'ir_dump' => 'IRDump',
)
loader.setup

module Kumi
end
