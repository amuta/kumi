# frozen_string_literal: true

module Kumi
  module Js
    # JavaScript transpiler for Kumi schemas
    # Extends the existing compiler architecture to output JavaScript instead of Ruby lambdas

    # Export a compiled schema to JavaScript
    def self.compile(schema_class, **options)
      syntax_tree = schema_class.__syntax_tree__
      analyzer_result = schema_class.__analyzer_result__

      compiler = Compiler.new(syntax_tree, analyzer_result)
      compiler.compile(**options)
    end

    # Export to JavaScript file
    def self.export_to_file(schema_class, filename, **options)
      js_code = compile(schema_class, **options)
      File.write(filename, js_code)
    end
  end
end
