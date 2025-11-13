# frozen_string_literal: true

require "zeitwerk"
require "mutex_m"
# require "pry" # COMMENT AFTER DEBUGGING

AUTOLOADER = Zeitwerk::Loader.for_gem
AUTOLOADER.ignore("#{__dir__}/kumi-cli")
AUTOLOADER.inflector.inflect(
  "assemble_irv2_pass" => "AssembleIRV2Pass",
  "ast_emitter" => "ASTEmitter",
  "attach_terminal_info_pass" => "AttachTerminalInfoPass",
  "cgir" => "CGIR",
  "df" => "DF",
  "global_cse_pass" => "GlobalCSEPass",
  "ir_dependency_pass" => "IRDependencyPass",
  "ir" => "IR",
  "ir_dump" => "IRDump",
  "ir_render" => "IRRender",
  "ir_execution_schedule_pass" => "IRExecutionSchedulePass",
  "irv2" => "IRV2",
  "irv2_formatter" => "IRV2Formatter",
  "lir" => "LIR",
  "lir_ruby_codegen_pass" => "LIRRubyCodegenPass",
  "lir_printer" => "LIRPrinter",
  "local_cse_pass" => "LocalCSEPass",
  "lower_to_ir_pass" => "LowerToIRPass",
  "lower_to_lir_pass" => "LowerToLIRPass",
  "lower_to_irv2_pass" => "LowerToIRV2Pass",
  "load_input_cse" => "LoadInputCSE",
  "nast" => "NAST",
  "normalize_to_nast_pass" => "NormalizeToNASTPass",
  "nast_dimensional_analyzer_pass" => "NASTDimensionalAnalyzerPass",
  "nast_printer" => "NASTPrinter",
  "snast_printer" => "SNASTPrinter",
  "snast_pass" => "SNASTPass",
  "ruby_ast" => "RubyAST",
  "vm" => "VM"
)
AUTOLOADER.setup

module Kumi
  # Provides access to the singleton configuration object.
  #
  # @return [Kumi::Configuration] the configuration instance
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Yields the configuration object to a block for user setup.
  # This is the main entry point for configuring Kumi in an application.
  #
  # Example (in config/initializers/kumi.rb):
  #   Kumi.configure do |config|
  #     config.cache_path = "/shared/cache/kumi"
  #   end
  def self.configure
    yield(configuration)
  end

  # A namespace for dynamically created compiled modules.
  module Compiled
  end

  # Load shared schemas only when explicitly requested (for golden tests)
  def self.load_shared_schemas!
    # Ensure JIT compilation mode for schemas being loaded
    Kumi.configure { |c| c.compilation_mode = :jit }

    AUTOLOADER.eager_load_dir("#{__dir__}/kumi/test_shared_schemas")
    # Populate GoldenSchemas module (already defined in golden_schema_modules.rb)
    Kumi::TestSharedSchemas.constants.each do |const|
      GoldenSchemas.const_set(const, Kumi::TestSharedSchemas.const_get(const)) unless GoldenSchemas.const_defined?(const)
    end
  end
end

# Load golden schema module base
require_relative "kumi/dev/golden_schema_modules"
