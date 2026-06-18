# frozen_string_literal: true

require_relative "source_frame"

module Kumi
  module Frontends
    module Ruby
      module_function

      def load(path:, inputs: {})
        src = File.read(path)

        begin
          [parse(src, path), inputs]
        rescue StandardError => e
          # Render the same `file:line: message` + code-frame the text frontend
          # produces. Located errors (SyntaxError/SemanticError) carry a Location;
          # anything else degrades to a clean `file: message` with no frame.
          raise StandardError, SourceFrame.render(e, src: src, file_label: path)
        end
      end

      def parse(src, path)
        mod = Module.new
        mod.extend(Kumi::Schema)
        begin
          mod.module_eval(src, path)
        rescue NameError => e
          raise translate_uppercase_reference(e, path) || e
        end

        # Extract just the syntax tree AST (same as Text frontend)
        if mod.const_defined?(:GoldenSchema)
          golden = mod.const_get(:GoldenSchema)
          golden.build if golden.respond_to?(:build)
          golden.__syntax_tree__
        elsif mod.__syntax_tree__
          mod.__syntax_tree__
        else
          raise "No schema AST found. Make sure the .rb file calls 'schema do...end'"
        end
      end

      # A bare reference to a declaration whose name starts with an uppercase
      # letter (e.g. `let :W` then `W`) is read by Ruby as a constant, not a
      # method, so the DSL's method_missing never sees it and Ruby raises a raw
      # `uninitialized constant ...::W`. The text frontend accepts such names, so
      # this is a Ruby-only limitation — turn it into a clear, located error
      # instead of leaking Ruby's anonymous-module constant message.
      def translate_uppercase_reference(error, path)
        const = error.name
        return nil unless const&.to_s&.match?(/\A[A-Z]/)
        return nil unless error.message.include?("uninitialized constant")

        frame = error.backtrace_locations&.find { |f| f.path == path }
        location = frame && Kumi::Syntax::Location.new(file: frame.path, line: frame.lineno, column: 0)

        Kumi::Core::Errors::SyntaxError.new(
          "`#{const}` looks like a reference to a declaration, but names starting " \
          "with an uppercase letter can't be referenced bare in the Ruby DSL " \
          "(Ruby reads them as constants). Use `ref(:#{const})`, or rename the " \
          "declaration to start with a lowercase letter.",
          location
        )
      end
    end
  end
end
