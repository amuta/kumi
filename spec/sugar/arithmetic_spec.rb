# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar arithmetic" do
  using Kumi::Core::RubyParser::Sugar::ExpressionRefinement
  using Kumi::Core::RubyParser::Sugar::NumericRefinement

  let(:lit) { Kumi::Syntax::Literal.new(2) }

  it "emits :add for + (Node on LHS)" do
    node = Kumi::Syntax::Literal.new(1) + lit
    expect(node).to be_a(Kumi::Syntax::CallExpression)
    expect(node.fn_name).to eq(:add)
  end

  it "emits :add for + (Numeric on LHS)" do
    node = 1 + Kumi::Syntax::Literal.new(2)
    expect(node.fn_name).to eq(:add)
  end

  it "normalizes all tokens" do
    a = Kumi::Syntax::Literal.new(7)
    b = Kumi::Syntax::Literal.new(3)
    expect((a - b).fn_name).to eq(:sub)
    expect((a * b).fn_name).to eq(:mul)
    expect((a / b).fn_name).to eq(:div)
    expect((a % b).fn_name).to eq(:mod)
    expect((a ** b).fn_name).to eq(:pow)
  end

  it "builds nested AST honoring precedence" do
    x = Kumi::Syntax::Literal.new(10)
    ast = 1 + x * 2
    expect(ast.fn_name).to eq(:add)
    rhs = ast.args.last # (x * 2)
    expect(rhs).to be_a(Kumi::Syntax::CallExpression)
    expect(rhs.fn_name).to eq(:mul)
  end

  it "unary minus maps to sub(0, expr)" do
    x = Kumi::Syntax::Literal.new(5)
    node = -x
    expect(node.fn_name).to eq(:sub)
    expect(node.args.first).to be_a(Kumi::Syntax::Literal)
    expect(node.args.first.value).to eq(0)
  end
end