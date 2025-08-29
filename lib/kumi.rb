# frozen_string_literal: true

require "zeitwerk"
# require "pry" # COMMENT AFTER DEBUGGING

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/kumi-cli")
loader.inflector.inflect(
  "lower_to_ir_pass" => "LowerToIRPass",
  "lower_to_irv2_pass" => "LowerToIRV2Pass",
  "load_input_cse" => "LoadInputCSE",
  "ir_dependency_pass" => "IRDependencyPass",
  "vm" => "VM",
  "ir" => "IR",
  "irv2" => "IRV2",
  "ir_dump" => "IRDump",
  "ir_render" => "IRRender",
  "ir_execution_schedule_pass" => "IRExecutionSchedulePass",
  "nast" => "NAST",
  "normalize_to_nast_pass" => "NormalizeToNASTPass",
  "nast_dimensional_analyzer_pass" => "NASTDimensionalAnalyzerPass",
  "snast_pass" => "SNASTPass",
  "nast_printer" => "NASTPrinter",
  "snast_printer" => "SNASTPrinter",
  "assemble_irv2_pass" => "AssembleIRV2Pass",
  "irv2_formatter" => "IRV2Formatter"
)
loader.setup

module Kumi
  IR_SCHEMA_VERSION = "0.1"
end
