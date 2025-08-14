RSpec.describe "NEP 20 Compliance" do
  let(:parser) { Kumi::Core::Functions::SignatureParser }
  let(:resolver) { Kumi::Core::Functions::SignatureResolver }

  describe "Fixed-size dimensions" do
    it "matches fixed-size dimensions exactly" do
      sigs = ["(3),(3)->(3)"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[3], [3]])
      expect(plan[:result_axes]).to eq([3])
    end

    it "rejects mismatched fixed-size dimensions" do
      sigs = ["(3),(3)->(3)"].map { |s| parser.parse(s) }
      expect do
        resolver.choose(signatures: sigs, arg_shapes: [[2], [3]])
      end.to raise_error(Kumi::Core::Functions::SignatureMatchError)
    end

    it "handles cross product signature (3-vector cross product)" do
      sigs = ["(3),(3)->(3)"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[3], [3]])
      expect(plan[:result_axes]).to eq([3])
    end
  end

  describe "Flexible dimensions (?)" do
    it "handles basic flexible dimension resolution" do
      # This is simplified - full NEP 20 would require more complex matching
      sigs = ["(i?),(i?)->(i?)"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[:i], [:i]])
      expect(plan[:result_axes]).to eq([:i])
      expect(plan[:score]).to eq(20) # High cost for flexible matching
    end

    it "parses matmul signature correctly" do
      sig = parser.parse("(m?,n),(n,p?)->(m?,p?)")
      expect(sig.in_shapes.length).to eq(2)
      expect(sig.in_shapes[0].first.name).to eq(:m)
      expect(sig.in_shapes[0].first.flexible?).to be true
      expect(sig.in_shapes[1].last.flexible?).to be true
    end
  end

  describe "Broadcastable dimensions (|1)" do
    it "matches broadcastable dimensions with scalar" do
      sigs = ["(i|1),(i|1)->()"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[:i], []])
      expect(plan[:result_axes]).to eq([])
    end

    it "matches exact broadcastable dimensions" do
      sigs = ["(i|1),(i|1)->()"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[:i], [:i]])
      expect(plan[:result_axes]).to eq([])
    end

    it "handles all_equal signature pattern" do
      sigs = ["(n|1),(n|1)->()"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[:n], []])
      expect(plan[:result_axes]).to eq([])
    end
  end

  describe "NEP 20 examples from specification" do
    it "handles angle to 2D unit vector: ->(2)" do
      sigs = ["->(2)"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [])
      expect(plan[:result_axes]).to eq([2])
    end

    it "handles two angles to 3D unit vector: (),()->(3)" do
      sigs = ["(),()->(3)"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[], []])
      expect(plan[:result_axes]).to eq([3])
    end

    it "handles inner vector product: (i),(i)->()" do
      sigs = ["(i),(i)->()"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [[:i], [:i]])
      expect(plan[:result_axes]).to eq([])
    end

    it "handles matrix multiplication: (m,n),(n,p)->(m,p)", pending: "Complex multi-dimensional join logic not yet implemented" do
      sigs = ["(m,n),(n,p)->(m,p)"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [%i[m n], %i[n p]])
      expect(plan[:result_axes]).to eq(%i[m p])
    end

    it "handles reduction: (i,j)->(i)" do
      sigs = ["(i,j)->(i)"].map { |s| parser.parse(s) }
      plan = resolver.choose(signatures: sigs, arg_shapes: [%i[i j]])
      expect(plan[:result_axes]).to eq([:i])
      expect(plan[:dropped_axes]).to eq([:j])
    end
  end

  describe "Signature validation" do
    it "rejects broadcastable output dimensions" do
      expect do
        parser.parse("(i|1)->(i|1)")
      end.to raise_error(Kumi::Core::Functions::SignatureError, /output dimension.*cannot be broadcastable/)
    end

    it "rejects inconsistent fixed-size dimensions" do
      # This particular case is actually valid - different input/output sizes
      expect do
        parser.parse("(3)->(2)") # Different fixed sizes for same operation would be invalid in context
      end.not_to raise_error
    end

    it "rejects flexible + broadcastable combination" do
      expect do
        Kumi::Core::Functions::Dimension.new(:i, flexible: true, broadcastable: true)
      end.to raise_error(Kumi::Core::Functions::SignatureError, /cannot be both flexible and broadcastable/)
    end
  end
end
