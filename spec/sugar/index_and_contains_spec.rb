# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar indexing & contains" do
  using Kumi::Core::RubyParser::Sugar::ExpressionRefinement
  using Kumi::Core::RubyParser::Sugar::ArrayRefinement

  it "[] becomes :get" do
    arr = Kumi::Syntax::ArrayExpression.new([Kumi::Syntax::Literal.new(1), Kumi::Syntax::Literal.new(2)])
    idx = Kumi::Syntax::Literal.new(0)
    call = arr[idx]
    expect(call.fn_name).to eq(:get)
    expect(call.args[0]).to eq(arr)
    expect(call.args[1]).to eq(idx)
  end

  it "include? becomes :contains (arrays with any syntax element)" do
    arr = [Kumi::Syntax::Literal.new("a"), "b"] # mixed types
    call = arr.include?(Kumi::Syntax::Literal.new("a"))
    expect(call.fn_name).to eq(:contains)
  end
end