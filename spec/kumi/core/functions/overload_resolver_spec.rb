# frozen_string_literal: true

RSpec.describe Kumi::Core::Functions::OverloadResolver do
  let(:registry) { Kumi::RegistryV2.load }
  let(:resolver) { described_class.new(registry.instance_variable_get(:@functions)) }

  describe "#resolve" do
    describe "with single overload" do
      it "resolves unambiguous functions by name" do
        resolved = resolver.resolve("add", [:integer, :integer])
        expect(resolved).to eq("core.add")
      end

      it "handles full function IDs" do
        resolved = resolver.resolve("core.add", [:integer, :integer])
        expect(resolved).to eq("core.add")
      end
    end

    describe "with multiple overloads (overloaded functions)" do
      it "resolves 'size' to core.length for string argument" do
        # size can mean both core.length (string) and core.array_size (array)
        resolved = resolver.resolve("size", [:string])
        expect(resolved).to eq("core.length")
      end

      it "resolves 'size' to core.array_size for array argument" do
        resolved = resolver.resolve("size", ["array<integer>"])
        expect(resolved).to eq("core.array_size")
      end

      it "resolves 'length' alias to core.length for string" do
        resolved = resolver.resolve("length", [:string])
        expect(resolved).to eq("core.length")
      end

      it "resolves 'array_size' alias to core.array_size for array" do
        resolved = resolver.resolve("array_size", ["array<integer>"])
        expect(resolved).to eq("core.array_size")
      end
    end

    describe "error handling" do
      it "raises ResolutionError for unknown function" do
        expect {
          resolver.resolve("nonexistent", [:integer])
        }.to raise_error(Kumi::Core::Functions::OverloadResolver::ResolutionError)
      end

      it "raises ResolutionError when no overload matches types" do
        expect {
          resolver.resolve("size", [:integer])  # integers don't have a "size" function
        }.to raise_error(Kumi::Core::Functions::OverloadResolver::ResolutionError)
      end

      it "raises ResolutionError for arity mismatch" do
        expect {
          resolver.resolve("core.add", [:integer])  # add needs 2 args
        }.to raise_error(Kumi::Core::Functions::OverloadResolver::ResolutionError)
      end

      it "provides helpful error messages with available overloads" do
        error = nil
        begin
          resolver.resolve("size", [:integer])
        rescue Kumi::Core::Functions::OverloadResolver::ResolutionError => e
          error = e
        end

        expect(error.message).to include("no overload of 'size'")
        expect(error.message).to include("Available overloads")
      end
    end
  end

  describe "#function" do
    it "retrieves function by ID" do
      fn = resolver.function("core.add")
      expect(fn.id).to eq("core.add")
    end

    it "raises ResolutionError for unknown function ID" do
      expect {
        resolver.function("nonexistent.fn")
      }.to raise_error(Kumi::Core::Functions::OverloadResolver::ResolutionError)
    end
  end

  describe "#exists?" do
    it "returns true for existing functions" do
      expect(resolver.exists?("core.add")).to be true
    end

    it "returns false for unknown functions" do
      expect(resolver.exists?("nonexistent")).to be false
    end

    it "handles symbol input" do
      expect(resolver.exists?(:"core.add")).to be true
    end
  end

  describe "type compatibility" do
    context "with no dtype constraint" do
      it "accepts any type" do
        # Most functions don't have dtype constraints on all params
        resolved = resolver.resolve("add", [:integer, :integer])
        expect(resolved).to eq("core.add")

        resolved = resolver.resolve("add", [:float, :float])
        expect(resolved).to eq("core.add")
      end
    end

    context "with dtype constraint" do
      it "matches string constraint" do
        resolved = resolver.resolve("upcase", [:string])
        expect(resolved).to eq("core.upcase")
      end

      it "matches array constraint" do
        resolved = resolver.resolve("array_size", ["array<integer>"])
        expect(resolved).to eq("core.array_size")
      end

      # Note: 'size' is an alias for both core.length (string) and core.array_size (array)
      # When given different types, it should pick the right overload
      it "picks correct overload for shared aliases" do
        # With string, should pick core.length
        resolved = resolver.resolve("size", [:string])
        expect(resolved).to eq("core.length")

        # With array, should pick core.array_size
        resolved = resolver.resolve("size", ["array<integer>"])
        expect(resolved).to eq("core.array_size")
      end
    end
  end
end
