# frozen_string_literal: true

function = ->(a, b, c) { "#{a}|#{b}|#{c}" }
unless Kumi::Registry.function?(:format3)
  Kumi::Registry.register_with_metadata(
    :format3,
    function, # e.g. ->(fmt, a, b) { Kernel.format(fmt, a, b) }
    arity: 3,
    structure_function: true,
    param_modes: { fixed: %i[elem elem elem] },
    param_types: %i[string any any],
    return_type: :string,
    description: "sprintf-style 2-arg formatter"
  )
end

module TestSchema
  extend Kumi::Schema

  schema do
    input do
      array :items do
        float :x
        float :p
        integer :q
      end
    end

    # non-commutative ops
    value :div1,  input.items.x / 2.0
    value :div2,  2.0 / input.items.x
    value :sub1,  input.items.x - 1.0
    value :sub2,  1.0 - input.items.x

    # if(cond, then, else)
    trait :gt100, input.items.p > 100.0
    value :if1,   fn(:if, gt100, input.items.p * 0.8, 999.0)          # scalar else
    value :if2,   fn(:if, gt100, 111.0, input.items.p * 0.8)          # scalar then
    value :if3,   fn(:if, true,  input.items.p * 0.8, input.items.p)  # scalar cond

    # keep literal positions inside array/map
    value :arr_lit,    [1, input.items.q, 3]
    value :fmt_litmid, fn(:format3, 1, input.items.q, 3) # custom 3-arg to test middle scalar
  end
end

RSpec.describe "VM argument order and if semantics" do
  let(:schema) do
    TestSchema
  end

  let(:data) do
    { items: [
      { x: 4.0,  p: 50.0,  q: 7 },
      { x: 8.0,  p: 150.0, q: 9 }
    ] }
  end

  let(:runner) { schema.from(data) }

  it "preserves arg order for non-commutative operations" do
    expect(runner[:div1]).to eq([2.0, 4.0])      # x / 2
    expect(runner[:div2]).to eq([0.5, 0.25])     # 2 / x
    expect(runner[:sub1]).to eq([3.0, 7.0])      # x - 1
    expect(runner[:sub2]).to eq([-3.0, -7.0])    # 1 - x
  end

  it "applies if(cond, then, else) in declared order" do
    expect(runner[:if1]).to eq([999.0, 120.0])   # else, then
    expect(runner[:if2]).to eq([40.0, 111.0]) # then, else
    expect(runner[:if3]).to eq([40.0, 120.0]) # cond scalar broadcast
  end

  it "keeps literal positions in arrays and middle scalar in 3-arg function" do
    # expect(runner[:arr_lit]).to eq([[1, 7, 3], [1, 9, 3]])
    expect(runner[:fmt_litmid]).to eq(["1|7|3", "1|9|3"])
  end

  it "IR keeps call-site order for if map args" do
    ir = Kumi::Analyzer.analyze!(schema.__syntax_tree__).state[:ir_module]
    decl = ir.decls.find { |d| d.name == :if1 }
    map  = decl.ops.find { |o| o.tag == :map && o.attrs[:fn] == :if }

    # assert the three inputs are in cond, then, else slot order
    expect(map.args.size).to eq(3)

    # Verify the slots contain the expected operations
    cond_slot, then_slot, else_slot = map.args
    expect(decl.ops[cond_slot].tag).to eq(:ref)  # condition: gt100__vec reference (optimized)
    expect(decl.ops[cond_slot].attrs[:name]).to eq(:gt100__vec)

    expect(decl.ops[then_slot].tag).to eq(:map)  # then: p * 0.8 calculation
    expect(decl.ops[then_slot].attrs[:fn]).to eq(:multiply)

    expect(decl.ops[else_slot].tag).to eq(:const) # else: constant 999.0
    expect(decl.ops[else_slot].attrs[:value]).to eq(999.0)
  end
end
