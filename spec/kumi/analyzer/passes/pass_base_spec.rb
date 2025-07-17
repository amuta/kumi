# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::PassBase do
  include ASTFactory

  # Create a concrete test pass to test the base functionality
  let(:test_pass_class) do
    Class.new(described_class) do
      def run(errors)
        # Test implementation that uses base class methods
        each_decl do |decl|
          add_error(errors, decl.loc, "test error for #{decl.name}")
        end
        set_state(:test_key, "test_value")
      end
    end
  end

  let(:schema) do
    attr1 = attr(:attr1, lit(1))
    trait1 = trait(:trait1, call(:>, lit(1), lit(0)))
    syntax(:root, [], [attr1], [trait1], loc: loc)
  end

  let(:state) { { existing: "data" } }
  let(:errors) { [] }
  let(:pass_instance) { test_pass_class.new(schema, state) }

  describe "#initialize" do
    it "stores schema and state" do
      expect(pass_instance.send(:schema)).to eq(schema)
      expect(pass_instance.send(:state)).to eq(state)
    end
  end

  describe "#run" do
    it "raises NotImplementedError for base class" do
      base_pass = described_class.new(schema, state)
      expect { base_pass.run(errors) }.to raise_error(NotImplementedError, /must implement #run/)
    end
  end

  describe "#each_decl" do
    it "iterates over all attributes and traits" do
      declarations = []
      pass_instance.send(:each_decl) { |decl| declarations << decl }

      expect(declarations.size).to eq(2)
      expect(declarations.map(&:name)).to contain_exactly(:attr1, :trait1)
      expect(declarations[0]).to be_a(Kumi::Syntax::Declarations::Attribute)
      expect(declarations[1]).to be_a(Kumi::Syntax::Declarations::Trait)
    end

    it "handles empty schema" do
      empty_schema = syntax(:root, [], [], [], loc: loc)
      empty_pass = test_pass_class.new(empty_schema, state)

      declarations = []
      empty_pass.send(:each_decl) { |decl| declarations << decl }

      expect(declarations).to be_empty
    end
  end

  describe "#add_error" do
    let(:location) { loc }
    let(:message) { "test error message" }

    it "adds error to errors array with correct format" do
      pass_instance.send(:add_error, errors, location, message)

      expect(errors.size).to eq(1)
      expect(errors.first).to eq([location, message])
    end

    it "handles nil location" do
      pass_instance.send(:add_error, errors, nil, message)

      expect(errors.size).to eq(1)
      expect(errors.first).to eq([nil, message])
    end
  end

  describe "#get_state" do
    context "when state key exists" do
      before { state[:existing_key] = "existing_value" }

      it "returns the state value" do
        value = pass_instance.send(:get_state, :existing_key)
        expect(value).to eq("existing_value")
      end

      it "returns the state value when not required" do
        value = pass_instance.send(:get_state, :existing_key, required: false)
        expect(value).to eq("existing_value")
      end
    end

    context "when state key does not exist" do
      it "raises error when required (default)" do
        expect { pass_instance.send(:get_state, :missing_key) }
          .to raise_error(/requires missing_key from previous passes/)
      end

      it "returns nil when not required" do
        value = pass_instance.send(:get_state, :missing_key, required: false)
        expect(value).to be_nil
      end
    end
  end

  describe "#set_state" do
    it "sets state value" do
      pass_instance.send(:set_state, :new_key, "new_value")

      expect(state[:new_key]).to eq("new_value")
    end

    it "overwrites existing state value" do
      state[:existing] = "old_value"
      pass_instance.send(:set_state, :existing, "new_value")

      expect(state[:existing]).to eq("new_value")
    end
  end

  describe "integration with concrete pass" do
    it "allows concrete passes to use all base functionality" do
      pass_instance.run(errors)

      # Check that each_decl and add_error worked
      expect(errors.size).to eq(2)
      expect(errors.map(&:last)).to contain_exactly(
        "test error for attr1",
        "test error for trait1"
      )

      # Check that set_state worked
      expect(state[:test_key]).to eq("test_value")
    end
  end

  describe "inheritance and method visibility" do
    it "exposes protected methods to subclasses" do
      # These methods should be accessible in subclasses
      expect(pass_instance.send(:respond_to?, :schema, true)).to be true
      expect(pass_instance.send(:respond_to?, :state, true)).to be true
      expect(pass_instance.send(:respond_to?, :each_decl, true)).to be true
      expect(pass_instance.send(:respond_to?, :add_error, true)).to be true
      expect(pass_instance.send(:respond_to?, :get_state, true)).to be true
      expect(pass_instance.send(:respond_to?, :set_state, true)).to be true
    end

    it "does not expose protected methods publicly" do
      # These methods should not be accessible from outside
      expect(pass_instance).not_to respond_to(:schema)
      expect(pass_instance).not_to respond_to(:state)
      expect(pass_instance).not_to respond_to(:each_decl)
    end
  end
end
