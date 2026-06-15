# frozen_string_literal: true

module Kumi
  module Syntax
    # Represents the root of the Abstract Syntax Tree.
    # It holds all the top-level declarations parsed from the source.
    Root = Struct.new(:inputs, :values, :traits, :imports) do
      include Node

      def children = [inputs, values, traits, imports]

      def digest
        # The digest must be stable and depend on anything that could change the
        # compiled output: the AST and the Kumi version (compiler changes). It is
        # deliberately Ruby-version-independent — the generated code is plain Ruby
        # with identical semantics across supported Rubies, so folding RUBY_VERSION
        # in would needlessly bust the compile cache and make codegen goldens
        # unverifiable across the CI Ruby matrix.
        digest_input = "#{Kumi::VERSION}-#{self}-#{hints.inspect}"

        # Ruby constants cannot start with a number, so we add a prefix.
        "KUMI_#{Digest::SHA256.hexdigest(digest_input)}"
      end
    end
  end
end
