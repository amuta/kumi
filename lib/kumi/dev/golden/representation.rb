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
          raise "Unknown generator method: #{generator_method}" unless PrettyPrinter.respond_to?(generator_method)

          PrettyPrinter.send(generator_method, schema_path)
        end
      end

      REPRESENTATIONS = [
        Representation.new("ast", extension: "txt"),
        Representation.new("input_plan", extension: "txt"),
        Representation.new("nast", extension: "txt"),
        Representation.new("snast", extension: "txt"),
        Representation.new("dfir", extension: "txt"),
        Representation.new("dfir_optimized", extension: "txt"),
        Representation.new("vecir", extension: "txt"),
        Representation.new("loopir", extension: "txt"),
        Representation.new("schema_ruby", extension: "rb"),
        Representation.new("schema_javascript", extension: "mjs")
      ].freeze
    end
  end
end
