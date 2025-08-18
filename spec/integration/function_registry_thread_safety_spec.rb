# frozen_string_literal: true

RSpec.describe Kumi::Registry, "function builder API" do
  before { described_class.reset! }

  context "single-threaded basics" do
    it "registers and looks up a function" do
      entry = described_class.define_eachwise("double") do |f|
        f.summary "Doubles a number"
        f.kernel { |x| x * 2 }
      end
      
      expect(described_class.custom_functions["double"]).to eq(entry)
      expect(entry.kernel.call(3)).to eq 6
    end

    it "rejects duplicate names" do
      described_class.define_eachwise("dup") do |f|
        f.summary "First function"
        f.kernel { 1 }
      end

      expect do
        described_class.define_eachwise("dup") do |f|
          f.summary "Duplicate function"
          f.kernel { 2 }
        end
      end.to raise_error(Kumi::Registry::BuildError, /already registered/i)
    end
  end

  context "thread-safety during concurrent registration" do
    it "remains consistent with many simultaneous writers" do
      names = (1..50).map { |n| "fn_#{n}" }  # Reduced for faster testing
      barrier = Queue.new

      threads = names.map do |name|
        Thread.new do
          barrier.pop # block until all threads are ready
          described_class.define_eachwise(name) do |f|
            f.summary "Function #{name}"
            f.kernel { name }
          end
        end
      end

      # release all threads at once
      names.size.times { barrier << true }
      threads.each(&:join)

      names.each do |name|
        entry = described_class.custom_functions[name]
        expect(entry).not_to be_nil
        expect(entry.kernel.call).to eq name
      end
    end
  end

  context "function builder features" do
    it "supports different function types" do
      # Test eachwise function
      described_class.define_eachwise("square") do |f|
        f.summary "Squares numbers"
        f.kernel { |x| x * x }
      end

      # Test aggregate function  
      described_class.define_aggregate("sum_safe") do |f|
        f.summary "Safe sum with identity"
        f.identity 0
        f.kernel { |arr| arr.sum }
      end

      eachwise_entry = described_class.custom_functions["square"]
      aggregate_entry = described_class.custom_functions["sum_safe"]

      expect(eachwise_entry).to be_eachwise
      expect(aggregate_entry).to be_aggregate
      expect(aggregate_entry.identity).to eq 0
    end
  end
end
