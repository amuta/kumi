# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar.ensure_literal" do
  let(:sugar) { Kumi::Core::RubyParser::Sugar }

  it "wraps plain Ruby values as Syntax::Literal" do
    lit = sugar.ensure_literal(42)
    expect(lit).to be_a(Kumi::Syntax::Literal)
    expect(lit.value).to eq(42)
  end

  it "passes through Syntax::Node" do
    node = Kumi::Syntax::Literal.new("x")
    expect(sugar.ensure_literal(node)).to equal(node)
  end

  it "calls to_ast_node if present" do
    stub = Class.new { def to_ast_node; Kumi::Syntax::Literal.new(:ok); end }.new
    lit = sugar.ensure_literal(stub)
    expect(lit).to be_a(Kumi::Syntax::Literal)
    expect(lit.value).to eq(:ok)
  end
end