# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::InputCollector do
  include ASTFactory

  let(:state) { Kumi::Core::Analyzer::AnalysisState.new }

  describe ".run" do
    context "when the schema has no inputs" do
      let(:schema) { syntax(:root, [], [], [], loc: loc) }

      it "leaves the input_meta empty and records no errors" do
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(result_state[:inputs]).to eq({})
        expect(errors).to be_empty
      end
    end

    context "with unique input field names" do
      let(:age_field) { syntax(:input_decl, :age, nil, :integer, loc: loc) }
      let(:name_field) { syntax(:input_decl, :name, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [age_field, name_field], [], [], loc: loc) }

      it "stores metadata for each field and reports zero errors" do
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        input_meta = result_state[:inputs]
        expect(input_meta.keys).to contain_exactly(:age, :name)
        expect(input_meta[:age]).to eq(type: :integer, domain: nil, access_mode: nil)
        expect(input_meta[:name]).to eq(type: :string, domain: nil, access_mode: nil)
      end
    end

    context "with input fields having domains" do
      let(:age_field) { syntax(:input_decl, :age, 18..65, :integer, loc: loc) }
      let(:status_field) { syntax(:input_decl, :status, %w[active inactive], :string, loc: loc) }
      let(:custom_field) { syntax(:input_decl, :custom, ->(v) { v > 0 }, :integer, loc: loc) }
      let(:schema) { syntax(:root, [age_field, status_field, custom_field], [], [], loc: loc) }

      it "stores domain metadata and validates domain types" do
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        input_meta = result_state[:inputs]
        expect(input_meta[:age][:domain]).to eq(18..65)
        expect(input_meta[:status][:domain]).to eq(%w[active inactive])
        expect(input_meta[:custom][:domain]).to be_a(Proc)
      end
    end

    context "with invalid domain types" do
      let(:bad_field) { syntax(:input_decl, :bad, "invalid_domain", :string, loc: loc) }
      let(:schema) { syntax(:root, [bad_field], [], [], loc: loc) }

      it "reports an error for invalid domain constraint" do
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
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        expect(result_state[:inputs][:dup]).to eq(type: :integer, domain: nil, access_mode: nil)
      end
    end

    context "when duplicate field names have conflicting types" do
      let(:field1) { syntax(:input_decl, :conflict, nil, :integer, loc: loc) }
      let(:field2) { syntax(:input_decl, :conflict, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [field1, field2], [], [], loc: loc) }

      it "reports a type conflict error" do
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
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors).to be_empty
        expect(result_state[:inputs][:partial]).to eq(type: :integer, domain: 0..100, access_mode: nil)
      end
    end

    context "when inputs contain non-InputDeclaration nodes" do
      let(:bad_node) { syntax(:literal, 42, loc: loc) }
      let(:good_field) { syntax(:input_decl, :good, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [bad_node, good_field], [], [], loc: loc) }

      it "reports an error for unexpected node type" do
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/Expected InputDeclaration node, got Kumi::Syntax::Literal/)
        # Should still process valid fields
        expect(result_state[:inputs][:good]).to eq(type: :string, domain: nil, access_mode: nil)
      end
    end

    context "with multiple invalid domains" do
      let(:field1) { syntax(:input_decl, :bad1, { invalid: true }, :any, loc: loc) }
      let(:field2) { syntax(:input_decl, :bad2, 123, :integer, loc: loc) }
      let(:field3) { syntax(:input_decl, :good, 0..10, :integer, loc: loc) }
      let(:schema) { syntax(:root, [field1, field2, field3], [], [], loc: loc) }

      it "reports errors for each invalid domain" do
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(errors.size).to eq(2)
        expect(errors[0].message).to match(/Field :bad1 has invalid domain constraint/)
        expect(errors[1].message).to match(/Field :bad2 has invalid domain constraint/)
        # Good field should still be processed
        expect(result_state[:inputs][:good]).to eq(type: :integer, domain: 0..10, access_mode: nil)
      end
    end

    context "with frozen input_meta result" do
      let(:field) { syntax(:input_decl, :test, nil, :string, loc: loc) }
      let(:schema) { syntax(:root, [field], [], [], loc: loc) }

      it "returns a frozen input_meta hash" do
        errors = []
        result_state = described_class.new(schema, state).run(errors)

        expect(result_state[:inputs]).to be_frozen
      end
    end

    context "with nested input declarations for vectorized arrays" do
      let(:schema) do
        inputs = [
          input_decl(:user_name, :string),
          input_decl(:line_items, :array, children: [
                       input_decl(:item_name, :string),
                       input_decl(:quantity, :integer),
                       input_decl(:tags, :array, children: [
                                    input_decl(:tag_name, :string)
                                  ])
                     ])
        ]
        syntax(:root, inputs, [], [], loc: loc)
      end

      it "builds a nested metadata hash that mirrors the AST structure" do
        errors = []
        result_state = described_class.new(schema, state).run(errors)
        input_meta = result_state[:inputs]

        expect(errors).to be_empty
        expect(input_meta.keys).to contain_exactly(:user_name, :line_items)
        expect(input_meta[:user_name]).to eq({ type: :string, domain: nil, access_mode: nil })

        # Verify the nested structure for line_items
        line_items_meta = input_meta[:line_items]
        expect(line_items_meta[:type]).to eq(:array)
        expect(line_items_meta).to have_key(:children)

        # Verify the children of the line_items elements
        item_children = line_items_meta[:children]
        expect(item_children.keys).to contain_exactly(:item_name, :quantity, :tags)
        expect(item_children[:item_name]).to eq({ type: :string, domain: nil, access_mode: nil })
        expect(item_children[:quantity]).to eq({ type: :integer, domain: nil, access_mode: nil })

        # Verify the deeply nested structure for tags
        tags_meta = item_children[:tags]
        expect(tags_meta[:type]).to eq(:array)
        expect(tags_meta[:children]).to eq({
                                             tag_name: { type: :string, domain: nil, access_mode: nil }
                                           })
      end
    end
  end
end
