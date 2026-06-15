# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::PassBase do
  def state_with(data)
    Kumi::Core::Analyzer::AnalysisState.new(data)
  end

  describe "contract DSL" do
    describe ".reads" do
      it "records required reads and defines a reader method" do
        klass = Class.new(described_class) { reads :foo }
        expect(klass.declared_reads).to eq([:foo])
        expect(klass.new(nil, state_with(foo: 42)).foo).to eq(42)
      end

      it "raises through the reader when a required key is missing" do
        klass = Class.new(described_class) { reads :foo }
        expect { klass.new(nil, state_with({})).foo }.to raise_error(StandardError, /foo/)
      end
    end

    describe ".optional_reads" do
      it "records optional reads and defines a nil-tolerant reader" do
        klass = Class.new(described_class) { optional_reads :maybe }
        expect(klass.declared_optional_reads).to eq([:maybe])
        expect(klass.new(nil, state_with({})).maybe).to be_nil
        expect(klass.new(nil, state_with(maybe: 1)).maybe).to eq(1)
      end
    end

    describe ".writes" do
      it "records written keys" do
        klass = Class.new(described_class) { writes :out_a, :out_b }
        expect(klass.declared_writes).to eq(%i[out_a out_b])
      end

      it "marks the contract declared even with no arguments" do
        klass = Class.new(described_class) { writes }
        expect(klass.declared_writes).to eq([])
        expect(klass.contract_declared?).to be(true)
      end
    end

    describe ".contract_declared?" do
      it "is false when no macro was called" do
        expect(Class.new(described_class).contract_declared?).to be(false)
      end

      it "is true when any macro was called" do
        expect(Class.new(described_class) { reads :x }.contract_declared?).to be(true)
      end
    end

    describe "inheritance" do
      it "merges contracts down the class hierarchy" do
        parent = Class.new(described_class) do
          reads :a
          writes :w
        end
        child = Class.new(parent) do
          reads :b
          optional_reads :o
        end
        expect(child.declared_reads).to eq(%i[a b])
        expect(child.declared_optional_reads).to eq([:o])
        expect(child.declared_writes).to eq([:w])
        expect(child.contract_declared?).to be(true)
      end
    end
  end
end
