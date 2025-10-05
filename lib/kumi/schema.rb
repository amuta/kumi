# frozen_string_literal: true

require "mutex_m"
require "digest"
require "fileutils"

module Kumi
  # This module is the main entry point for users of the Kumi DSL.
  # When a user module `extend`s this, it gains the `schema` block method
  # and the `from` class method to execute the compiled logic.
  module Schema
    # The `__syntax_tree__` is available on the class for introspection.
    attr_reader :__kumi_syntax_tree__, :__kumi_compiled_module__

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

      __kumi_compiled_module__.from({})
    end

    def from(input_data)
      ensure_compiled!
      __kumi_compiled_module__.from(input_data)
    end

    private

    def ensure_compiled!
      @kumi_compile_lock ||= Mutex.new
      @kumi_compile_lock.synchronize do
        # We check `force_recompile` here to allow for debugging the compiler.
        return if @kumi_compiled && !Kumi.configuration.force_recompile

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
        @kumi_compiled = true
      end
    end

    def compile_and_write_cache(cache_path, digest)
      # 1. Run the full analysis pipeline.
      @__kumi_analyzer_result__ = Kumi::Analyzer.analyze!(@__kumi_syntax_tree__)

      # 2. Extract the generated code from the final state object.
      compiler_output = @__kumi_analyzer_result__.state[:ruby_codegen_files]["codegen.rb"]
      raise "Compiler did not produce ruby_codegen_files" unless compiler_output

      FileUtils.mkdir_p(File.dirname(cache_path))
      # Write to a temporary file and then move it to prevent race conditions
      # where another process might try to read a partially written file.
      temp_path = "#{cache_path}.#{Process.pid}-#{rand(1000)}"
      File.write(temp_path, compiler_output)
      FileUtils.mv(temp_path, cache_path)
    end
  end
end
