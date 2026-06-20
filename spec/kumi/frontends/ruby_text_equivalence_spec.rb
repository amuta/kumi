# frozen_string_literal: true

require "tmpdir"

# The Ruby DSL frontend and the text (`.kumi`) frontend must produce the SAME
# `Kumi::Syntax::Root` AST for source that is valid in both. The same string is
# legal Ruby (with the DSL refinements) and legal Kumi text, so each case here
# feeds one source through both frontends and asserts `==`.
#
# This is the real regression net for the Ruby frontend: the goldens only run
# the text frontend, so they cannot catch a Ruby-frontend regression. Cases are
# lifted from real golden schemas to track the schemas we actually ship.
RSpec.describe "Ruby/Text frontend AST equivalence" do
  def equivalent?(src)
    Dir.mktmpdir("equiv") do |dir|
      rb = File.join(dir, "s.rb")
      ku = File.join(dir, "s.kumi")
      File.write(rb, src)
      File.write(ku, src)

      ruby_ast, = Kumi::Frontends::Ruby.load(path: rb)
      text_ast, = Kumi::Frontends::Text.load(path: ku)

      [ruby_ast, text_ast]
    end
  end

  shared_examples "produces identical ASTs" do |src|
    it "parses to the same Root from both frontends" do
      ruby_ast, text_ast = equivalent?(src)

      expect(ruby_ast).to be_a(Kumi::Syntax::Root)
      expect(text_ast).to be_a(Kumi::Syntax::Root)
      expect(ruby_ast).to eq(text_ast)
    end
  end

  context "scalar arithmetic and traits" do
    it_behaves_like "produces identical ASTs", <<~SCHEMA
      schema do
        input do
          integer :x
          integer :y
        end

        value :sum, input.x + input.y
        trait :positive_sum, sum > 0
      end
    SCHEMA
  end

  context "multi-trait cascade (cascade_logic golden)" do
    it_behaves_like "produces identical ASTs", File.read(
      File.expand_path("../../../golden/cascade_logic/schema.kumi", __dir__)
    )
  end

  context "decimal casts and let (decimal_explicit golden)" do
    it_behaves_like "produces identical ASTs", File.read(
      File.expand_path("../../../golden/decimal_explicit/schema.kumi", __dir__)
    )
  end

  context "nested hash inputs (nested_hash golden)" do
    it_behaves_like "produces identical ASTs", File.read(
      File.expand_path("../../../golden/nested_hash/schema.kumi", __dir__)
    )
  end
end
