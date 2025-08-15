# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar ProxyRefinement" do
  module DummyProxyHelpers
    def to_ast_node; Kumi::Syntax::Literal.new(:P); end
  end

  class DummyProxy
    extend Kumi::Core::RubyParser::Sugar::ProxyRefinement
    include DummyProxyHelpers
  end

  it "supports arithmetic via to_ast_node" do
    n = DummyProxy.new + 1
    expect(n).to be_a(Kumi::Syntax::CallExpression)
    expect(n.fn_name).to eq(:add)
    expect(n.args.first).to be_a(Kumi::Syntax::Literal) # :P
  end

  it "[] becomes :get" do
    call = DummyProxy.new[0]
    expect(call.fn_name).to eq(:get)
  end

  it "nil? turns into eq(nil)" do
    call = DummyProxy.new.nil?
    expect(call.fn_name).to eq(:eq)
    expect(call.args.last).to be_a(Kumi::Syntax::Literal)
    expect(call.args.last.value).to be_nil
  end
end