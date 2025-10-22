# frozen_string_literal: true

require "mutex_m"
require "digest"
require "fileutils"

module Kumi
  # Thin wrapper providing backward-compatible interface for pure module functions.
  # The compiled module now contains only module-level functions (def self._name(input)),
  # but users expect an instance-like interface with .from(), .update(), [].
  # This wrapper bridges that gap.
  class CompiledSchemaWrapper
    def initialize(compiled_module, input_data)
      @compiled_module = compiled_module
      @input = input_data
    end

    def [](declaration_name)
      method_name = "_#{declaration_name}"
      unless @compiled_module.respond_to?(method_name)
        raise KeyError, "Unknown declaration: #{declaration_name}"
      end
      @compiled_module.public_send(method_name, @input)
    end

    def update(new_input)
      @input = @input.merge(new_input)
      self
    end

    def from(new_input)
      CompiledSchemaWrapper.new(@compiled_module, new_input)
    end

    private

    attr_reader :compiled_module, :input
  end

  # This module is the main entry point for users of the Kumi DSL.
  # When a user module `extend`s this, it gains the `schema` block method
  # and the `from` class method to execute the compiled logic.
  module Schema
    # The `__syntax_tree__` is available on the class for introspection.
    attr_reader :__kumi_syntax_tree__, :__kumi_compiled_module__
    alias __syntax_tree__ __kumi_syntax_tree__

    def build_syntax_tree(&)
      @__kumi_syntax_tree__ = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&)
    end

    def schema(&block)
      @__kumi_syntax_tree__ = Kumi::Core::RubyParser::Dsl.build_syntax_tree(&block)
      # Store the location where the schema was defined. This is essential for caching
      # and providing good error messages.
      @kumi_source_location = block.source_location.first

      ensure_compiled!
    end

    def schema_metadata
      ensure_compiled!
      SchemaMetadata.new(@__kumi_analyzer_result__.state, @__kumi_syntax_tree__)
    end

    def runner
      ensure_compiled!

      CompiledSchemaWrapper.new(__kumi_compiled_module__, {})
    end

    def from(input_data)
      ensure_compiled!
      CompiledSchemaWrapper.new(__kumi_compiled_module__, input_data)
    end

    def write_source(file_path, platform: :ruby)
      raise "No schema defined" unless @__kumi_syntax_tree__
      raise ArgumentError, "platform must be :ruby or :javascript" unless %i[ruby javascript].include?(platform)

      result = Kumi::Analyzer.analyze!(@__kumi_syntax_tree__)

      code = case platform
             when :ruby
               result.state[:ruby_codegen_files]&.fetch("codegen.rb", nil)
             when :javascript
               result.state[:javascript_codegen_files]&.fetch("codegen.mjs", nil)
             end

      raise "Compiler did not produce #{platform}_codegen_files" unless code

      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, code)
      file_path
    end

    private

    def ensure_compiled!
      @kumi_compile_lock ||= Mutex.new
      @kumi_compile_lock.synchronize do
        # We check `force_recompile` here to allow for debugging the compiler.
        return if @kumi_compiled && !Kumi.configuration.force_recompile

        @__kumi_analyzer_result__ = Kumi::Analyzer.analyze!(@__kumi_syntax_tree__)

        schema_digest = @__kumi_syntax_tree__.digest
        cache_path = File.join(Kumi.configuration.cache_path, "#{schema_digest}.rb")

        # This is the core JIT vs. AOT logic.
        case Kumi.configuration.compilation_mode
        when :jit
          compile_and_write_cache(cache_path, schema_digest) unless File.exist?(cache_path)
        when :aot
          unless File.exist?(cache_path) && !Kumi.configuration.force_recompile
            raise "Schema #{name} is not precompiled for digest #{schema_digest}. Please run the `kumi:compile` build task."
          end
        else
          raise "Invalid Kumi compilation mode: #{Kumi.configuration.compilation_mode}"
        end

        # Load the dynamically generated but statically cached file.
        require cache_path

        # The loaded file defined a module inside Kumi::Compiled. We now include it
        # to mix in the compiled methods (_total_payroll, etc.) and the instance
        # method `__kumi_compiled_module__`.
        @__kumi_compiled_module__ = Kumi::Compiled.const_get(schema_digest)

        # Extend the schema module/class with the compiled module so that
        # pure module functions like _declaration_name(input) are available directly.
        # This allows schema imports to work: GoldenSchemas::Tax._tax({amount: 100})
        self.singleton_class.include(@__kumi_compiled_module__)

        @kumi_compiled = true
      end
    end

    def compile_and_write_cache(cache_path, _digest)
      # 1. Extract the generated code from the final state object.
      compiler_output = @__kumi_analyzer_result__.state[:ruby_codegen_files]["codegen.rb"]
      raise "Compiler did not produce ruby_codegen_files" unless compiler_output

      FileUtils.mkdir_p(File.dirname(cache_path))
      File.write(cache_path, compiler_output)
    end
  end
end
