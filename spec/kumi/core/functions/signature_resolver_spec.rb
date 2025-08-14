RSpec.describe Kumi::Core::Functions::SignatureResolver do
  it "chooses broadcast over exact when needed" do
    sigs = ["(i),(i)->(i)", "(),(i)->(i)"].map { Kumi::Core::Functions::SignatureParser.parse(_1) }
    plan = described_class.choose(signatures: sigs, arg_shapes: [[], [:i]])
    expect(plan[:result_axes]).to eq([:i])
  end

  it "detects reduction axis" do
    sigs = ["(i,j)->(i)"].map { Kumi::Core::Functions::SignatureParser.parse(_1) }
    plan = Kumi::Core::Functions::SignatureResolver.choose(signatures: sigs, arg_shapes: [%i[i j]])
    expect(plan[:dropped_axes]).to eq([:j])
  end

  it "rejects implicit zip when axes differ and policy absent" do
    sigs = ["(i),(i)->(i)"].map { Kumi::Core::Functions::SignatureParser.parse(_1) }
    expect do
      Kumi::Core::Functions::SignatureResolver.choose(signatures: sigs, arg_shapes: [[:i], [:j]])
    end.to raise_error(Kumi::Core::Functions::SignatureMatchError)
  end
end
