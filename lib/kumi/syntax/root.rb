# frozen_string_literal: true

module Kumi
  module Syntax
    # Represents the root of the Abstract Syntax Tree.
    # It holds all the top-level declarations parsed from the source.
    Root = Struct.new(:inputs, :values, :traits) do
      include Node

      def children = [inputs, values, traits]

      def digest
        # The digest must be stable and depend on anything that could change the
        # compiled output. This includes the AST, the Kumi version (compiler changes),
        # and the Ruby version (runtime behavior changes).
        digest_input = "#{Kumi::VERSION}-#{RUBY_VERSION}-#{self}"

        # Ruby constants cannot start with a number, so we add a prefix.
        "KUMI_#{Digest::SHA256.hexdigest(digest_input)}"
      end
    end
  end
end
