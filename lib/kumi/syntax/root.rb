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
        # with identical semantics across supported Rubies, so a version-sensitive
        # digest would needlessly bust the compile cache and make the codegen
        # goldens unverifiable across the CI Ruby matrix.
        #
        # The AST is serialized through a format-pinned encoder rather than
        # `inspect`/`to_s`, because `Struct#to_s` and `Hash#inspect` changed their
        # rendering in Ruby 3.4 (`{:a=>1}` → `{a: 1}`), which would otherwise leak
        # the Ruby version into the hash.
        digest_input = "#{Kumi::VERSION}-#{Digest::SHA256.hexdigest(self.class.stable_encode([self, hints]))}"

        # Ruby constants cannot start with a number, so we add a prefix.
        "KUMI_#{Digest::SHA256.hexdigest(digest_input)}"
      end

      # Recursively encode an AST fragment into a string whose format does not
      # depend on the Ruby version (unlike `inspect`/`to_s`). Structs are encoded
      # by class name + ordered members; collections and scalars by an explicit
      # tagged form. `loc` is intentionally excluded — it does not affect codegen.
      def self.stable_encode(value)
        case value
        when Kumi::Syntax::Node
          members = value.respond_to?(:members) ? value.members : []
          fields = members.map { |m| "#{m}=#{stable_encode(value[m])}" }
          "#{value.class.name}(#{fields.join(',')};hints=#{stable_encode(value.hints)})"
        when Array
          "[#{value.map { |v| stable_encode(v) }.join(',')}]"
        when Hash
          pairs = value.map { |k, v| "#{stable_encode(k)}=>#{stable_encode(v)}" }.sort
          "{#{pairs.join(',')}}"
        when Symbol
          ":#{value}"
        when String
          value.dump
        else
          value.to_s
        end
      end
    end
  end
end
