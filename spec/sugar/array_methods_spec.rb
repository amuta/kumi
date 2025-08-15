# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar array methods" do
  using Kumi::Core::RubyParser::Sugar::ArrayRefinement

  it "sum lifts to CallExpression(:sum, [ArrayExpression])" do
    arr = [Kumi::Syntax::Literal.new(1), 2, 3]
    call = arr.sum
    expect(call.fn_name).to eq(:sum)
    expect(call.args[0]).to be_a(Kumi::Syntax::ArrayExpression)
  end

  it "size lifts to CallExpression(:size, [ArrayExpression])" do
    arr = [Kumi::Syntax::Literal.new(1), 2]
    call = arr.size
    expect(call.fn_name).to eq(:size)
  end

  it "include? → :contains with argument" do
    arr = [Kumi::Syntax::Literal.new(1), 2]
    call = arr.include?(Kumi::Syntax::Literal.new(2))
    expect(call.fn_name).to eq(:contains)
  end
end