# frozen_string_literal: true

require "zeitwerk"
require "pry" # COMMENT AFTER DEBUGGING

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/kumi-cli")
loader.inflector.inflect(
  "lir" => "LIR",
  "lir_ruby_codegen_pass" => "LIRRubyCodegenPass",
  "lower_to_ir_pass" => "LowerToIRPass",
  "lower_to_lir_pass" => "LowerToLIRPass",
  "lower_to_irv2_pass" => "LowerToIRV2Pass",
  "load_input_cse" => "LoadInputCSE",
  "ir_dependency_pass" => "IRDependencyPass",
  "ir" => "IR",
  "ir_dump" => "IRDump",
  "ir_render" => "IRRender",
  "ir_execution_schedule_pass" => "IRExecutionSchedulePass",
  "irv2" => "IRV2",
  "irv2_formatter" => "IRV2Formatter",
  "nast" => "NAST",
  "normalize_to_nast_pass" => "NormalizeToNASTPass",
  "nast_dimensional_analyzer_pass" => "NASTDimensionalAnalyzerPass",
  "snast_pass" => "SNASTPass",
  "attach_terminal_info_pass" => "AttachTerminalInfoPass",
  "nast_printer" => "NASTPrinter",
  "snast_printer" => "SNASTPrinter",
  "lir_printer" => "LIRPrinter",
  "lir_validation_pass" => "LIRValidationPass",
  "lir_inline_declarations_pass" => "LIRInlineDeclarationsPass",
  "lir_local_cse_pass" => "LIRLocalCSEPass",
  "lir_hois_constants_pass" => "LIRHoistConstantsPass",
  "assemble_irv2_pass" => "AssembleIRV2Pass",
  "cgir" => "CGIR",
  "vm" => "VM"
)
loader.setup

module Kumi
  IR_SCHEMA_VERSION = "0.1"
end
