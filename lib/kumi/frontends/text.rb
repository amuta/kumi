# frozen_string_literal: true

module Kumi
  module Frontends
    module Text
      module_function
      
      def load(path:, inputs: {})
        src = File.read(path)
        
        # For now, we'll create a placeholder that requires kumi-parser
        # This will be implemented once kumi-parser gem is available
        begin
          require "kumi-parser"
          schema = Kumi::Parser::TextParser.parse(src)
          Core::Analyzer::Debug.info(:parse, kind: :text, file: path, ok: true) if Core::Analyzer::Debug.enabled?
        rescue LoadError
          raise "kumi-parser gem not available. Install with: gem install kumi-parser"
        rescue => e
          # Normalize diagnostics
          loc = (e.respond_to?(:location) && e.location) || {}
          msg = "#{path}:#{loc[:line] || '?'}:#{loc[:column] || '?'}: #{e.message}"
          raise StandardError, msg
        end
        
        [schema, inputs]
      end
    end
  end
end