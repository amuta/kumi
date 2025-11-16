# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::Vec::Validator do
  let(:vec_module) { Kumi::IR::Vec::Module.new(name: :demo) }
  let(:function) do
    Kumi::IR::Base::Function.new(
      name: :compute,
      blocks: [Kumi::IR::Base::Block.new(name: :entry)]
    )
  end
  let(:builder) { Kumi::IR::Vec::Builder.new(ir_module: vec_module, function:) }
  let(:int_type) { ir_types.scalar(:integer) }

  before do
    vec_module.add_function(function)
  end

  it "accepts valid Vec modules" do
    a = builder.load_input(result: :a, key: :a, axes: %i[row col], dtype: int_type)
    b = builder.load_input(result: :b, key: :b, axes: %i[row col], dtype: int_type)
    builder.map(result: :sum, fn: :"core.add", args: [a, b], axes: %i[row col], dtype: int_type)

    expect { described_class.validate!(vec_module) }.not_to raise_error
  end

  it "rejects tuple dtypes" do
    tuple_type = ir_types.tuple([int_type, int_type])
    builder.constant(result: :neighbors, value: [], axes: [], dtype: tuple_type)

    expect { described_class.validate!(vec_module) }.to raise_error(ArgumentError, /tuple dtype/)
  end

  it "rejects unsupported opcodes" do
    block = function.entry_block
    block.append(Kumi::IR::DF::Ops::ArrayBuild.new(result: :tuple, elements: [], axes: [], dtype: tuple_type = ir_types.tuple([])))

    expect { described_class.validate!(vec_module) }.to raise_error(ArgumentError, /does not support opcode/)
  end
end
