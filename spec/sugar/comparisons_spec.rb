# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Sugar comparisons" do
  using Kumi::Core::RubyParser::Sugar::ExpressionRefinement
  using Kumi::Core::RubyParser::Sugar::NumericRefinement
  using Kumi::Core::RubyParser::Sugar::StringRefinement

  let(:x) { Kumi::Syntax::Literal.new(5) }

  it { expect((x == 5).fn_name).to eq(:eq) }
  it { expect((x != 5).fn_name).to eq(:ne) }
  it { expect((x <  5).fn_name).to eq(:lt) }
  it { expect((x <= 5).fn_name).to eq(:le) }
  it { expect((x >  5).fn_name).to eq(:gt) }
  it { expect((x >= 5).fn_name).to eq(:ge) }

  it "works when LHS is a Ruby literal" do
    node = 5 < Kumi::Syntax::Literal.new(8)
    expect(node.fn_name).to eq(:lt)
  end
end