# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::InputCollector do
  include ASTFactory

  describe ".run" do
    context "when the schema has no inputs" do
      let(:schema) { syntax(:root, [], [], [], loc: loc) }

      it "leaves the input_meta empty and records no errors" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(result_state[:input_meta]).to eq({})
        expect(errors).to be_empty
      end
    end

    context "with unique input field names" do
      let(:age_field) { syntax(:input_decl, :age, nil, :integer, loc: loc) }
      let(:name_field) { syntax(:input_decl, :name, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [age_field, name_field], [], [], loc: loc) }

      it "stores metadata for each field and reports zero errors" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        input_meta = result_state[:input_meta]
        expect(input_meta.keys).to contain_exactly(:age, :name)
        expect(input_meta[:age]).to eq(type: :integer, domain: nil)
        expect(input_meta[:name]).to eq(type: :string, domain: nil)
      end
    end

    context "with input fields having domains" do
      let(:age_field) { syntax(:input_decl, :age, 18..65, :integer, loc: loc) }
      let(:status_field) { syntax(:input_decl, :status, %w[active inactive], :string, loc: loc) }
      let(:custom_field) { syntax(:input_decl, :custom, ->(v) { v > 0 }, :integer, loc: loc) }
      let(:schema) { syntax(:root, [age_field, status_field, custom_field], [], [], loc: loc) }

      it "stores domain metadata and validates domain types" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        input_meta = result_state[:input_meta]
        expect(input_meta[:age][:domain]).to eq(18..65)
        expect(input_meta[:status][:domain]).to eq(%w[active inactive])
        expect(input_meta[:custom][:domain]).to be_a(Proc)
      end
    end

    context "with invalid domain types" do
      let(:bad_field) { syntax(:input_decl, :bad, "invalid_domain", :string, loc: loc) }
      let(:schema) { syntax(:root, [bad_field], [], [], loc: loc) }

      it "reports an error for invalid domain constraint" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/Field :bad has invalid domain constraint/)
        expect(errors.first.message).to match(/Domain must be a Range, Array, or Proc/)
      end
    end

    context "when duplicate field names appear with same metadata" do
      let(:field1) { syntax(:input_decl, :dup, nil, :integer, loc: loc) }
      let(:field2) { syntax(:input_decl, :dup, nil, :integer, loc: loc) }
      let(:schema) { syntax(:root, [field1, field2], [], [], loc: loc) }

      it "merges without error since metadata matches" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        expect(result_state[:input_meta][:dup]).to eq(type: :integer, domain: nil)
      end
    end

    context "when duplicate field names have conflicting types" do
      let(:field1) { syntax(:input_decl, :conflict, nil, :integer, loc: loc) }
      let(:field2) { syntax(:input_decl, :conflict, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [field1, field2], [], [], loc: loc) }

      it "reports a type conflict error" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/Field :conflict declared with conflicting types: integer vs string/)
      end
    end

    context "when duplicate field names have conflicting domains" do
      let(:field1) { syntax(:input_decl, :age, 18..65, :integer, loc: loc) }
      let(:field2) { syntax(:input_decl, :age, 21..70, :integer, loc: loc) }
      let(:schema) { syntax(:root, [field1, field2], [], [], loc: loc) }

      it "reports a domain conflict error" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/Field :age declared with conflicting domains: 18\.\.65 vs 21\.\.70/)
      end
    end

    context "when merging fields with partial metadata" do
      let(:field1) { syntax(:input_decl, :partial, nil, :integer, loc: loc) }
      let(:field2) { syntax(:input_decl, :partial, 0..100, nil, loc: loc) }
      let(:schema) { syntax(:root, [field1, field2], [], [], loc: loc) }

      it "merges non-nil values without conflict" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        expect(result_state[:input_meta][:partial]).to eq(type: :integer, domain: 0..100)
      end
    end

    context "when inputs contain non-InputDeclaration nodes" do
      let(:bad_node) { syntax(:literal, 42, loc: loc) }
      let(:good_field) { syntax(:input_decl, :good, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [bad_node, good_field], [], [], loc: loc) }

      it "reports an error for unexpected node type" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/Expected InputDeclaration node, got Kumi::Syntax::Literal/)
        # Should still process valid fields
        expect(result_state[:input_meta][:good]).to eq(type: :string, domain: nil)
      end
    end

    context "with multiple invalid domains" do
      let(:field1) { syntax(:input_decl, :bad1, { invalid: true }, :any, loc: loc) }
      let(:field2) { syntax(:input_decl, :bad2, 123, :integer, loc: loc) }
      let(:field3) { syntax(:input_decl, :good, 0..10, :integer, loc: loc) }
      let(:schema) { syntax(:root, [field1, field2, field3], [], [], loc: loc) }

      it "reports errors for each invalid domain" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(2)
        expect(errors[0].message).to match(/Field :bad1 has invalid domain constraint/)
        expect(errors[1].message).to match(/Field :bad2 has invalid domain constraint/)
        # Good field should still be processed
        expect(result_state[:input_meta][:good]).to eq(type: :integer, domain: 0..10)
      end
    end

    context "with frozen input_meta result" do
      let(:field) { syntax(:input_decl, :test, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [field], [], [], loc: loc) }

      it "returns a frozen input_meta hash" do
        state = Kumi::Analyzer::AnalysisState.new
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(result_state[:input_meta]).to be_frozen
      end
    end
  end
end