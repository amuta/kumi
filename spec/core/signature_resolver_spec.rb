# frozen_string_literal: true
require "spec_helper"

RSpec.describe Kumi::Core::Functions::SignatureResolver do
  def parse_all(*sigs)
    sigs.flatten.map { |s| Kumi::Core::Functions::SignatureParser.parse(s) }
  end

  it "chooses broadcast over exact when needed (scalar extension explicit)" do
    sigs = parse_all("(i),(i)->(i)", "(),(i)->(i)")
    plan = described_class.choose(signatures: sigs, arg_shapes: [[], [:i]])
    expect(plan[:result_axes]).to eq([:i])
  end

  it "detects reduction axis from a 2D signature" do
    sigs = parse_all("(i,j)->(i)")
    plan = described_class.choose(signatures: sigs, arg_shapes: [[:i, :j]])
    expect(plan[:dropped_axes]).to eq([:j])
    expect(plan[:result_axes]).to eq([:i])
  end

  it "rejects implicit zip when axes differ and policy absent" do
    sigs = parse_all("(i),(i)->(i)")
    expect {
      described_class.choose(signatures: sigs, arg_shapes: [[:i], [:j]])
    }.to raise_error(Kumi::Core::Functions::SignatureMatchError)
  end

  # ---------- New behavior: cell match + lifting over Outer ----------

  it "lifts reducers over leading outer axes (3D -> 2D) (will fail until lifting is implemented)" do
    # mean (i)->() applied to [:companies,:employees,:projects] should drop :projects and keep the outer axes
    sigs = parse_all("(i)->()") # canonical 1-D reducer signature
    plan = described_class.choose(
      signatures: sigs,
      arg_shapes: [[:companies, :employees, :projects]]
    )
    expect(plan[:result_axes]).to eq([:companies, :employees])
    expect(plan[:dropped_axes]).to eq([:projects]) # semantic, not :i
  end

  it "performs elementwise scalar extension without needing an explicit scalar signature (will fail until lifting is implemented)" do
    # gt is elementwise 0-D cell; comparing [:companies,:employees] with scalar [] should succeed
    sigs = parse_all("(i),(i)->(i)") # canonical same-shape binary; scalar extension handled by matcher
    plan = described_class.choose(
      signatures: sigs,
      arg_shapes: [[:companies, :employees], []]
    )
    expect(plan[:result_axes]).to eq([:companies, :employees])
  end

  it "binds signature variables to semantic axis names (will fail until lifting is implemented)" do
    sigs = parse_all("(i,j)->(i)")
    plan = described_class.choose(
      signatures: sigs,
      arg_shapes: [[:companies, :projects]]
    )
    # var :i binds to :companies, var :j binds to :projects
    expect(plan[:result_axes]).to eq([:companies])
    expect(plan[:dropped_axes]).to eq([:projects])
    expect(plan[:env].keys).to include(:i, :j)
  end

  it "requires same OUTER for elementwise zip (will fail until lifting is implemented)" do
    sigs = parse_all("(i),(i)->(i)")
    # Outer differs: [:departments] vs [:projects]
    expect {
      described_class.choose(
        signatures: sigs,
        arg_shapes: [[:departments, :employees], [:projects, :employees]]
      )
    }.to raise_error(Kumi::Core::Functions::SignatureMatchError, /outer/i)
  end

  it "accepts flexible optional tail dims in the cell (NEP-20 ?), still lifted (will fail until lifting is implemented)" do
    # Suppose a reducer that can drop j if present: (i,?j)->(i)
    sigs = parse_all("(i,?j)->(i)")
    # Arg has only i in the cell position; extra leading is outer (e.g., companies)
    plan = described_class.choose(
      signatures: sigs,
      arg_shapes: [[:companies, :i]]
    )
    expect(plan[:result_axes]).to eq([:companies, :i])
    expect(plan[:dropped_axes]).to eq([]) # j optional and absent
  end

  it "honors broadcastable 1-dims (|1) for size-1 tails (will fail until lifting is implemented)" do
    # Example: (i|1),(i)->(i) — left may be scalar/size-1 vector in the cell position
    sigs = parse_all("(i|1),(i)->(i)")
    plan = described_class.choose(
      signatures: sigs,
      arg_shapes: [[1, :employees], [:departments, :employees]] # 1 here means fixed-size 1 tail
    )
    expect(plan[:result_axes]).to eq([:departments, :employees])
  end

  it "prefers exact cell match over broadcast when both applicable (will fail until lifting is implemented)" do
    sigs = parse_all("(i),(i)->(i)", "(),(i)->(i)")
    # Both could match, but exact (i),(i)->(i) should score better than scalar broadcast
    plan = described_class.choose(
      signatures: sigs,
      arg_shapes: [[:employees], [:employees]]
    )
    expect(plan[:effective_signature][:in_shapes]).to eq([[:i], [:i]])
  end
end