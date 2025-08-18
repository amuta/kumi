# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Simple Function Builder" do

  it "registers an each-wise function and exposes its kernel" do
    entry = Kumi::Registry.define_eachwise("math.square") do |f|
      f.summary "Squares numbers"
      f.kernel  { |x| x * x }
    end

    expect(entry.name).to eq("math.square")
    expect(entry).to be_eachwise
    expect(entry.signatures).to eq(["()->()", "(i)->(i)"])
    expect(entry.null_policy).to eq(:propagate)
    expect(entry.zip_policy).to eq(:zip)

    # Kernel sanity check
    expect(entry.kernel.call(5)).to eq(25)
  end

  it "raises a helpful error if required fields are missing" do
    expect do
      Kumi::Registry.define_eachwise("string.titleize") do |f|
        f.summary "Missing kernel on purpose"
        # no kernel
      end
    end.to raise_error(Kumi::Registry::BuildError, /Missing:\n- kernel:/)
  end

  it "registers an aggregate with identity and works on empty inputs" do
    sum = Kumi::Registry.define_aggregate("agg.sum_safe") do |f|
      f.summary  "Sum with identity"
      f.identity 0
      f.kernel { |arr| arr.inject(0) { |acc, x| acc + x } }
    end

    expect(sum.name).to eq("agg.sum_safe")
    expect(sum).to be_aggregate
    expect(sum.signatures).to eq(["(i)->()"])
    expect(sum.identity).to eq(0)
    expect(sum.null_policy).to eq(:skip)

    # Kernel sanity checks
    expect(sum.kernel.call([1,2,3])).to eq(6)
    expect(sum.kernel.call([])).to eq(0)  # uses identity on empty
  end
end