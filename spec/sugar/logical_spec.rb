# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar logical" do
  using Kumi::Core::RubyParser::Sugar::ExpressionRefinement

  let(:a) { Kumi::Syntax::Literal.new(true) }
  let(:b) { Kumi::Syntax::Literal.new(false) }

  it { expect((a & b).fn_name).to eq(:and) }
  it { expect((a | b).fn_name).to eq(:or) }
end