# frozen_string_literal: true

module Kumi
  module Dev
    module Golden
      class Representation
        attr_reader :name, :extension, :generator_method

        def initialize(name, extension:, generator: nil)
          @name = name
          @extension = extension
          @generator_method = generator || "generate_#{name}"
        end

        def filename
          "#{name}.#{extension}"
        end

        def generate(schema_path)
          unless PrettyPrinter.respond_to?(generator_method)
            raise "Unknown generator method: #{generator_method}"
          end

          PrettyPrinter.send(generator_method, schema_path)
        end
      end

      REPRESENTATIONS = [
        Representation.new("ast", extension: "txt"),
        Representation.new("input_plan", extension: "txt"),
        Representation.new("nast", extension: "txt"),
        Representation.new("snast", extension: "txt"),
        Representation.new("lir_00_unoptimized", extension: "txt"),
        Representation.new("lir_01_hoist_scalar_references", extension: "txt"),
        Representation.new("lir_02_inlined", extension: "txt"),
        Representation.new("lir_04_1_loop_fusion", extension: "txt"),
        Representation.new("lir_03_cse", extension: "txt"),
        Representation.new("lir_04_loop_invcm", extension: "txt"),
        Representation.new("lir_06_const_prop", extension: "txt"),
        Representation.new("schema_ruby", extension: "rb"),
        Representation.new("schema_javascript", extension: "mjs")
      ].freeze
    end
  end
end
