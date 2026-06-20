# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Validator do
  let(:int_type) { ir_types.scalar(:integer) }

  def graph_with(*instructions)
    block = df_block(instructions:)
    fn = df_function(name: :demo, blocks: [block])
    Kumi::IR::DF::Graph.new(name: :demo, functions: [fn])
  end

  it "rejects load_input instructions that mix plan_ref and traversal chain" do
    graph = graph_with(
      df_ops::LoadInput.new(
        result: :v1,
        key: :rows,
        chain: ["rows"],
        plan_ref: "rows",
        axes: [],
        dtype: int_type,
        metadata: { axes: [], dtype: int_type }
      )
    )

    expect { described_class.validate!(graph) }
      .to raise_error(ArgumentError, /load_input with plan_ref must be root-only/)
  end

  it "accepts root-only load_input instructions with plan_ref" do
    graph = graph_with(
      df_ops::LoadInput.new(
        result: :v1,
        key: :rows,
        chain: [],
        plan_ref: "rows",
        axes: [],
        dtype: int_type,
        metadata: { axes: [], dtype: int_type }
      )
    )

    expect(described_class.validate!(graph)).to eq(graph)
  end

  it "accepts fold instructions only when pre-canonical fold is allowed" do
    tuple_type = ir_types.tuple([int_type, int_type])
    graph = graph_with(
      df_ops::Constant.new(result: :v1, value: 1, axes: [], dtype: int_type, metadata: { axes: [], dtype: int_type }),
      df_ops::Constant.new(result: :v2, value: 2, axes: [], dtype: int_type, metadata: { axes: [], dtype: int_type }),
      df_ops::ArrayBuild.new(result: :tuple, elements: %i[v1 v2], axes: [], dtype: tuple_type, metadata: { axes: [], dtype: tuple_type }),
      df_ops::Fold.new(result: :sum, fn: :"agg.sum", arg: :tuple, axes: [], dtype: int_type, metadata: { axes: [], dtype: int_type })
    )

    expect(described_class.validate!(graph, allow_fold: true)).to eq(graph)
    expect { described_class.validate!(graph) }
      .to raise_error(ArgumentError, /does not support opcode fold/)
  end

  it "rejects axis reductions with empty over_axes over non-tuple values" do
    graph = graph_with(
      df_ops::LoadInput.new(
        result: :v1,
        key: :rows,
        chain: [],
        plan_ref: "rows",
        axes: %i[rows],
        dtype: int_type,
        metadata: { axes: %i[rows], dtype: int_type }
      ),
      df_ops::Reduce.new(result: :sum, fn: :"agg.sum", arg: :v1, axes: %i[rows], over_axes: [], dtype: int_type,
                         metadata: { axes: %i[rows], dtype: int_type })
    )

    expect { described_class.validate!(graph) }
      .to raise_error(ArgumentError, /reduce missing over_axes/)
  end

  it "accepts load_field instructions that append axes from a container value" do
    graph = graph_with(
      df_ops::LoadInput.new(
        result: :items,
        key: :items,
        chain: [],
        plan_ref: "items",
        axes: [],
        dtype: ir_types.array(int_type),
        metadata: { axes: [], dtype: ir_types.array(int_type) }
      ),
      df_ops::LoadField.new(
        result: :value,
        object: :items,
        field: :value,
        plan_ref: "items.value",
        axes: %i[items],
        dtype: int_type,
        metadata: { axes: %i[items], dtype: int_type }
      )
    )

    expect(described_class.validate!(graph)).to eq(graph)
  end

  it "rejects load_field instructions that drop source axes" do
    graph = graph_with(
      df_ops::LoadInput.new(
        result: :items,
        key: :items,
        chain: [],
        plan_ref: "items",
        axes: %i[items],
        dtype: int_type,
        metadata: { axes: %i[items], dtype: int_type }
      ),
      df_ops::LoadField.new(
        result: :value,
        object: :items,
        field: :value,
        plan_ref: "items.value",
        axes: [],
        dtype: int_type,
        metadata: { axes: [], dtype: int_type }
      )
    )

    expect { described_class.validate!(graph) }
      .to raise_error(ArgumentError, /load_field must preserve or expand axes/)
  end

  describe "registry coherence" do
    let(:registry) { Kumi::FunctionRegistry.load }

    def map_graph(fn)
      graph_with(
        df_ops::Constant.new(result: :v1, value: 1, axes: [], dtype: int_type, metadata: { axes: [], dtype: int_type }),
        df_ops::Constant.new(result: :v2, value: 2, axes: [], dtype: int_type, metadata: { axes: [], dtype: int_type }),
        df_ops::Map.new(result: :out, fn: fn, args: %i[v1 v2], axes: [], dtype: int_type,
                        metadata: { axes: [], dtype: int_type })
      )
    end

    it "accepts function references that resolve to kernels for every target" do
      expect(described_class.validate!(map_graph(:"core.add"), registry: registry)).to be_a(Kumi::IR::DF::Graph)
    end

    it "rejects function references the registry does not know" do
      expect { described_class.validate!(map_graph(:"core.definitely_missing"), registry: registry) }
        .to raise_error(ArgumentError, /map :out in function :demo references :"core\.definitely_missing".*unknown function/)
    end

    it "rejects functions without a kernel for an enabled target" do
      partial = Class.new do
        def kernel_for(id, target:)
          raise "no kernel for #{id} on #{target}" if target == :javascript

          :kernel
        end
      end.new

      expect { described_class.validate!(map_graph(:"core.add"), registry: partial) }
        .to raise_error(ArgumentError, /no kernel for core\.add on javascript/)
    end

    it "skips the check when no registry is given" do
      expect { described_class.validate!(map_graph(:"core.definitely_missing")) }.not_to raise_error
    end
  end
end
