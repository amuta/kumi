# frozen_string_literal: true

RSpec.describe Kumi::Registry, "thread-safety & immutability" do
  let(:core) { Kumi::Core::FunctionRegistry }

  before { described_class.reset! }

  context "single-threaded basics" do
    it "registers and looks up a function" do
      described_class.register(:double) { |x| x * 2 }
      expect(described_class.fetch(:double).call(3)).to eq 6
    end

    it "rejects duplicate names" do
      described_class.register(:dup) { 1 }

      expect do
        described_class.register(:dup) { 2 }
      end.to raise_error(ArgumentError, /already registered/i)
    end
  end

  context "thread-safety during concurrent registration" do
    it "remains consistent with many simultaneous writers" do
      names    = (1..500).map { |n| :"fn_#{n}" }
      barrier  = Queue.new

      threads = names.map do |name|
        Thread.new do
          barrier.pop # block until all threads are ready
          described_class.register(name) { name }
        end
      end

      # release all threads at once
      names.size.times { barrier << true }
      threads.each(&:join)

      names.each do |name|
        expect(described_class.fetch(name).call).to eq name
      end
    end
  end

  context "immutability after freeze!" do
    it "blocks further registrations once frozen" do
      described_class.register(:initial) { 0 }
      described_class.freeze!

      expect do
        described_class.register(:later) { 1 }
      end.to raise_error(core::FrozenError, /frozen/i)

      expect(described_class.fetch(:initial).call).to eq 0
    end
  end

  context "freeze semantics" do
    it "deep-freezes functions" do
      described_class.register(:foo) { |x| x }
      described_class.freeze!

      expect do
        described_class.register(:bar) { 1 }
      end.to raise_error(core::FrozenError)
    end

    it "freezes the functions hash and every entry inside it" do
      # boot-time registration
      described_class.reset!
      described_class.register(:foo) { |x| x }

      # lock the registry
      described_class.freeze!

      # inspect the *core* registry internals (facade has no @functions)
      functions = core.instance_variable_get(:@functions)

      # hash itself is frozen
      expect(functions).to be_frozen

      # trying to add or remove keys fails (built-in FrozenError)
      expect { functions[:bar] = proc { 1 } }.to raise_error(FrozenError)
      expect { functions.delete(:foo) }.to raise_error(FrozenError)

      # each Entry is frozen too
      foo_entry = functions[:foo]
      expect(foo_entry).to be_frozen

      # if your Entry exposes nested metadata, ensure that’s frozen as well
      expect { foo_entry.meta[:arity] = 99 }.to raise_error(FrozenError) if foo_entry.respond_to?(:meta)
    end
  end
end
