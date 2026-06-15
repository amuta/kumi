# frozen_string_literal: true

RSpec.describe "Kumi::Core::NAST children protocol" do
  let(:nast) { Kumi::Core::NAST }
  let(:const_a) { nast::Const.new(value: 1) }
  let(:const_b) { nast::Const.new(value: 2) }

  it "returns [] for leaf nodes" do
    expect(const_a.children).to eq([])
    expect(nast::InputRef.new(path: [:x]).children).to eq([])
    expect(nast::Ref.new(name: :y).children).to eq([])
    expect(nast::IndexRef.new(name: :i, input_fqn: "x").children).to eq([])
  end

  it "returns args for call-like nodes" do
    call = nast::Call.new(fn: :add, args: [const_a, const_b])
    tuple = nast::Tuple.new(args: [const_a])
    expect(call.children).to eq([const_a, const_b])
    expect(tuple.children).to eq([const_a])
  end

  it "returns operand structure for select, fold, reduce, declaration" do
    select = nast::Select.new(cond: const_a, on_true: const_b, on_false: const_a)
    fold = nast::Fold.new(fn: :sum, arg: const_a)
    reduce = nast::Reduce.new(fn: :sum, over: [:i], arg: const_b)
    decl = nast::Declaration.new(name: :d, body: const_a)
    expect(select.children).to eq([const_a, const_b, const_a])
    expect(fold.children).to eq([const_a])
    expect(reduce.children).to eq([const_b])
    expect(decl.children).to eq([const_a])
  end

  it "returns node-valued parts of pairs and hashes" do
    pair = nast::Pair.new(key: const_a, value: const_b)
    expect(pair.children).to eq([const_a, const_b])

    symbol_pair = nast::Pair.new(key: :k, value: const_b)
    expect(symbol_pair.children).to eq([const_b])

    hash = nast::Hash.new(pairs: [pair])
    expect(hash.children).to eq([pair])
  end

  it "returns declarations for modules" do
    decl = nast::Declaration.new(name: :d, body: const_a)
    mod = nast::Module.new(decls: { d: decl })
    expect(mod.children).to eq([decl])
  end
end
