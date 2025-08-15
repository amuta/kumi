# frozen_string_literal: true
require "spec_helper"

RSpec.describe Kumi::Core::Naming::BasenameNormalizer do
  it { expect(described_class.normalize(:multiply)).to eq(:mul) }
  it { expect(described_class.normalize(:at)).to eq(:get) }
  it { expect(described_class.normalize(:'include?')).to eq(:contains) }
  it { expect(described_class.normalize(:gte)).to eq(:ge) }
  it { expect(described_class.normalize(:'==')).to eq(:eq) }
  it { expect(described_class.normalize(:subtract)).to eq(:sub) }
  it { expect(described_class.normalize(:divide)).to eq(:div) }
  it { expect(described_class.normalize(:modulo)).to eq(:mod) }
  it { expect(described_class.normalize(:power)).to eq(:pow) }
  it { expect(described_class.normalize(:'!=')).to eq(:ne) }
  it { expect(described_class.normalize(:<)).to eq(:lt) }
  it { expect(described_class.normalize(:<=)).to eq(:le) }
  it { expect(described_class.normalize(:>)).to eq(:gt) }
  it { expect(described_class.normalize(:>=)).to eq(:ge) }
  it { expect(described_class.normalize(:lte)).to eq(:le) }
  it { expect(described_class.normalize(:"&")).to eq(:and) }
  it { expect(described_class.normalize(:"|")).to eq(:or) }
  it { expect(described_class.normalize(:"!")).to eq(:not) }

  it "returns canonical names unchanged" do
    expect(described_class.normalize(:add)).to eq(:add)
    expect(described_class.normalize(:sub)).to eq(:sub)
    expect(described_class.normalize(:get)).to eq(:get)
    expect(described_class.normalize(:contains)).to eq(:contains)
  end

  it "handles string inputs" do
    expect(described_class.normalize("multiply")).to eq(:mul)
    expect(described_class.normalize("add")).to eq(:add)
  end
end