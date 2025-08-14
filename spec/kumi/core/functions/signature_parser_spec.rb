RSpec.describe Kumi::Core::Functions::SignatureParser do
  it "parses zip" do
    s = described_class.parse("(i),(i)->(i)")
    expect(s.in_shapes).to eq([[Kumi::Core::Functions::Dimension.new(:i)], [Kumi::Core::Functions::Dimension.new(:i)]])
    expect(s.out_shape).to eq([Kumi::Core::Functions::Dimension.new(:i)])
    expect(s.join_policy).to be_nil
  end

  it "parses product" do
    s = described_class.parse("(i),(j)->(i,j)@product")
    expect(s.join_policy).to eq(:product)
  end

  it "parses fixed-size dimensions" do
    s = described_class.parse("(3),(3)->(3)")
    expect(s.in_shapes).to eq([[Kumi::Core::Functions::Dimension.new(3)], [Kumi::Core::Functions::Dimension.new(3)]])
    expect(s.out_shape).to eq([Kumi::Core::Functions::Dimension.new(3)])
  end

  it "parses flexible dimensions" do
    s = described_class.parse("(i?),(i?)->(i?)")
    expected_dim = Kumi::Core::Functions::Dimension.new(:i, flexible: true)
    expect(s.in_shapes).to eq([[expected_dim], [expected_dim]])
    expect(s.out_shape).to eq([expected_dim])
  end

  it "parses broadcastable dimensions" do
    s = described_class.parse("(i|1),(i|1)->()")
    expected_dim = Kumi::Core::Functions::Dimension.new(:i, broadcastable: true)
    expect(s.in_shapes).to eq([[expected_dim], [expected_dim]])
    expect(s.out_shape).to eq([])
  end
end
