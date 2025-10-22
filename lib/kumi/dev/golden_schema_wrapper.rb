# frozen_string_literal: true

module Kumi
  module Dev
    # Wraps golden test schemas as importable Ruby modules
    # Allows golden schemas to import from other golden schemas
    #
    # Usage:
    #   tax_schema = GoldenSchemaWrapper.load('golden/tax_rate/schema.kumi')
    #   Schemas::Tax = GoldenSchemaWrapper.as_module(tax_schema, 'Schemas::Tax')
    #
    #   # Now other schemas can: import :calculate_tax, from: Schemas::Tax
    class GoldenSchemaWrapper
      # Load a golden schema from a .kumi file
      def self.load(path)
        full_path = File.expand_path(path)
        raise "Schema file not found: #{full_path}" unless File.exist?(full_path)

        content = File.read(full_path)
        # Parse using the standard parser
        root = Kumi::Core::RubyParser::Dsl.build_syntax_tree { instance_eval(content) }
        root
      end

      # Wrap a schema root in a module that can be used for imports
      # Creates: module_const with kumi_schema_instance method
      def self.as_module(schema_root, const_path)
        # Create nested module structure: Schemas::Tax, Schemas::Payment, etc
        parts = const_path.split("::")
        module_name = parts.pop
        parent_path = parts.empty? ? "Object" : parts.join("::")

        # Get or create parent module
        parent = if parent_path == "Object"
          Object
        else
          parts.inject(Object) do |mod, part|
            if mod.const_defined?(part, false)
              mod.const_get(part)
            else
              new_mod = Module.new
              mod.const_set(part, new_mod)
              new_mod
            end
          end
        end

        # Analyze the schema to get metadata
        analyzed_state = analyze_schema(schema_root)
        input_metadata = extract_input_metadata(schema_root)

        # Create the schema module
        schema_module = Module.new do
          define_singleton_method :kumi_schema_instance do
            @instance ||= create_instance(schema_root, analyzed_state, input_metadata)
          end

          define_singleton_method :create_instance do |root, state, meta|
            schema_obj = Object.new
            def schema_obj.root
              @root_ast
            end

            def schema_obj.input_metadata
              @input_metadata
            end

            def schema_obj.analyzed_state
              @analyzed_state
            end

            schema_obj.instance_variable_set(:@root_ast, root)
            schema_obj.instance_variable_set(:@input_metadata, meta)
            schema_obj.instance_variable_set(:@analyzed_state, state)
            schema_obj
          end
        end

        parent.const_set(module_name, schema_module)
        schema_module
      end

      private

      def self.analyze_schema(schema_root)
        # Run full analysis on the schema
        registry = Kumi::RegistryV2.load
        state = Kumi::Core::Analyzer::AnalysisState.new({})
        state = state.with(:registry, registry)
        errors = []

        # Run DEFAULT_PASSES
        Kumi::Analyzer::DEFAULT_PASSES.each do |pass_class|
          pass = pass_class.new(schema_root, state)
          state = pass.run(errors)
          raise "Analysis failed: #{errors.map(&:to_s).join(', ')}" unless errors.empty?
        end

        state
      end

      def self.extract_input_metadata(schema_root)
        metadata = {}
        return metadata unless schema_root.inputs

        schema_root.inputs.each do |input_decl|
          metadata[input_decl.name] = {
            type: input_decl.type_spec&.kind || :any
          }
        end

        metadata
      end
    end
  end
end
