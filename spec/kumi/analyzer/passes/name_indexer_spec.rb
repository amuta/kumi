# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::NameIndexer do
  include ASTFactory

  # compact location literal

  describe ".run" do
    context "when the schema is empty" do
      let(:schema) { syntax(:root, [], [], [], loc: loc) }

      it "leaves the state empty and records no errors" do
        state = {}
        errors = []
        described_class.new(schema, state).run(errors)

        expect(state[:definitions]).to eq({})
        expect(errors).to be_empty
      end
    end

    context "with unique attribute and trait names" do
      let(:price_attribute) { attr(:price, lit(100)) }
      let(:vip_trait) { trait(:vip, call(:is_vip, ref(:price))) }
      let(:schema) { syntax(:root, [], [price_attribute], [vip_trait], loc: loc) }

      it "stores each declaration and reports zero errors" do
        state = {}
        errors = []
        described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        expect(state[:definitions].keys).to contain_exactly(:price, :vip)
        expect(state[:definitions][:price]).to be_a(Kumi::Syntax::Declarations::Attribute)
        expect(state[:definitions][:vip]).to be_a(Kumi::Syntax::Declarations::Trait)
      end
    end

    context "when duplicate attribute names appear" do
      # let(:schema) { syntax(:root, [attr(:dup), attr(:dup)], [], loc: loc) }
      let(:dup_attribute) { attr(:dup, lit(1)) }
      let(:dup_attribute_two) { attr(:dup, lit(2)) }
      let(:schema) { syntax(:root, [], [dup_attribute, dup_attribute_two], []) }

      it "records a single duplicate-definition error" do
        state = {}
        errors = []
        described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(errors.first.last).to match(/duplicated definition `dup`/)
      end
    end

    context "when an attribute and a trait share the same name" do
      let(:schema) { syntax(:root, [], [attr(:conflict)], [trait(:conflict, call(:is_conflict))], loc: loc) }

      it "registers the duplicate and keeps the last declaration in the map" do
        state = {}
        errors = []
        described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(state[:definitions][:conflict]).to be_a(Kumi::Syntax::Declarations::Trait)
      end
    end
  end
end
