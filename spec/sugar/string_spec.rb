# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar string" do
  using Kumi::Core::RubyParser::Sugar::StringRefinement

  it "string + expr becomes :concat" do
    expr = Kumi::Syntax::Literal.new("X")
    node = "hello " + expr
    expect(node.fn_name).to eq(:concat)
  end

  it "== and != with syntax emit eq/ne" do
    expr = Kumi::Syntax::Literal.new("hi")
    expect(("hi" == expr).fn_name).to eq(:eq)
    expect(("hi" != expr).fn_name).to eq(:ne)
  end
end