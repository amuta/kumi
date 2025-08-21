# frozen_string_literal: true

module Kumi
  module Frontends
    module Ruby
      module_function
      
      def load(path:, inputs: {})
        mod = Module.new
        mod.extend(Kumi::Schema)
        mod.module_eval(File.read(path), path)
        
        # Extract just the syntax tree AST (same as Text frontend)
        schema_ast = if mod.const_defined?(:GoldenSchema)
          golden = mod.const_get(:GoldenSchema)
          golden.build if golden.respond_to?(:build)
          golden.__syntax_tree__
        elsif mod.__syntax_tree__
          mod.__syntax_tree__
        else
          raise "No schema AST found. Make sure the .rb file calls 'schema do...end'"
        end
        
        [schema_ast, inputs]
      end
    end
  end
end