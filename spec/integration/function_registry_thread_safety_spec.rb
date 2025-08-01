# frozen_string_literal: true

# Focus: prove that Kumi::Registry.behaves correctly under
# concurrent writes, duplicate-name attempts, and post-boot freezing.
#
# Assumes these API helpers exist:
#   - Kumi::Registry.reset!
#   - Kumi::Registry.register(name, &block)
#   - Kumi::Registry.fetch(name)
#   - Kumi::Registry.freeze!
RSpec.describe Kumi::Registry, "thread-safety & immutability" do
  before { Kumi::Registry.reset! }

  context "single-threaded basics" do
    it "registers and looks up a function" do
      Kumi::Registry.register(:double) { |x| x * 2 }
      expect(Kumi::Registry.fetch(:double).call(3)).to eq 6
    end

    it "rejects duplicate names" do
      Kumi::Registry.register(:dup) { 1 }

      expect do
        Kumi::Registry.register(:dup) { 2 }
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
          Kumi::Registry.register(name) { name }
        end
      end

      # release all threads at once
      names.size.times { barrier << true }
      threads.each(&:join)

      names.each do |name|
        expect(Kumi::Registry.fetch(name).call).to eq name
      end
    end
  end

  context "immutability after freeze!" do
    it "blocks further registrations once frozen" do
      Kumi::Registry.register(:initial) { 0 }
      Kumi::Registry.freeze!

      expect do
        Kumi::Registry.register(:later) { 1 }
      end.to raise_error(RuntimeError, /frozen/i)

      expect(Kumi::Registry.fetch(:initial).call).to eq 0
    end
  end

  context "freeze semantics" do
    it "deep-freezes functions" do
      Kumi::Registry.register(:foo) { |x| x }
      Kumi::Registry.freeze!

      expect do
        Kumi::Registry.register(:bar) { 1 }
      end.to raise_error(Kumi::Registry::FrozenError)
    end

    it "freezes the functions hash and every entry inside it" do
      # boot-time registration
      Kumi::Registry.register(:foo) { |x| x }

      # lock the registry
      Kumi::Registry.freeze!

      functions = Kumi::Registry.instance_variable_get(:@functions)

      # hash itself is frozen
      expect(functions).to be_frozen

      # trying to add or remove keys fails
      expect do
        functions[:bar] = proc { 1 }
      end.to raise_error(FrozenError)

      expect do
        functions.delete(:foo)
      end.to raise_error(FrozenError)

      # each Entry (or Proc, depending on impl) is frozen too
      foo_entry = functions[:foo]
      expect(foo_entry).to be_frozen

      # mutating nested metadata should also fail
      if foo_entry.respond_to?(:meta)
        expect do
          foo_entry.meta[:arity] = 99
        end.to raise_error(FrozenError)
      end
    end
  end
end
