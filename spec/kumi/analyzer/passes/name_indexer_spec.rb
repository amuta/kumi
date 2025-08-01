# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::NameIndexer do
  include ASTFactory

  # compact location literal

  describe ".run" do
    context "when the schema is empty" do
      let(:schema) { syntax(:root, [], [], [], loc: loc) }

      it "leaves the state empty and records no errors" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(result_state[:declarations]).to eq({})
        expect(errors).to be_empty
      end
    end

    context "with unique attribute and trait names" do
      let(:price_attribute) { attr(:price, lit(100)) }
      let(:vip_trait) { trait(:vip, call(:is_vip, ref(:price))) }
      let(:schema) { syntax(:root, [], [price_attribute], [vip_trait], loc: loc) }

      it "stores each declaration and reports zero errors" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        definitions = result_state[:declarations]
        expect(definitions.keys).to contain_exactly(:price, :vip)
        expect(definitions[:price]).to be_a(Kumi::Syntax::ValueDeclaration)
        expect(definitions[:vip]).to be_a(Kumi::Syntax::TraitDeclaration)
      end
    end

    context "when duplicate attribute names appear" do
      # let(:schema) { syntax(:root, [attr(:dup), attr(:dup)], [], loc: loc) }
      let(:dup_attribute) { attr(:dup, lit(1)) }
      let(:dup_attribute_two) { attr(:dup, lit(2)) }
      let(:schema) { syntax(:root, [], [dup_attribute, dup_attribute_two], []) }

      it "records a single duplicate-definition error" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/duplicated definition `dup`/)
      end
    end

    context "when an attribute and a trait share the same name" do
      let(:schema) { syntax(:root, [], [attr(:conflict)], [trait(:conflict, call(:is_conflict))], loc: loc) }

      it "registers the duplicate and keeps the last declaration in the map" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(result_state[:declarations][:conflict]).to be_a(Kumi::Syntax::TraitDeclaration)
      end
    end
  end
end
