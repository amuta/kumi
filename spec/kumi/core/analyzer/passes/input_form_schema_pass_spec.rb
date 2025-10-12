# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::InputFormSchemaPass do
  include SchemaGenerator

  let(:schema) do
    Kumi::Core::RubyParser::Dsl.build_syntax_tree do
      input do
        array :items do
          hash :item do
            float :price
            integer :quantity
            string :category
          end
        end
        float :tax_rate
      end

      value :total, 0.0
    end
  end

  let(:result) { Kumi::Analyzer.analyze!(schema) }

  describe "basic form schema generation" do
    it "generates form schema from input metadata" do
      form_schema = result.state[:input_form_schema]

      expect(form_schema).not_to be_nil
      expect(form_schema).to be_a(Hash)
    end

    it "creates scalar field representation" do
      form_schema = result.state[:input_form_schema]

      expect(form_schema[:tax_rate]).to eq({ type: :float })
    end

    it "creates array field with element representation" do
      form_schema = result.state[:input_form_schema]

      expect(form_schema[:items][:type]).to eq(:array)
      expect(form_schema[:items][:element]).not_to be_nil
    end

    it "creates object field with fields representation" do
      form_schema = result.state[:input_form_schema]
      element = form_schema[:items][:element]

      expect(element[:type]).to eq(:object)
      expect(element[:fields]).to be_a(Hash)
      expect(element[:fields].keys).to contain_exactly(:price, :quantity, :category)
    end

    it "preserves scalar types in nested fields" do
      form_schema = result.state[:input_form_schema]
      fields = form_schema[:items][:element][:fields]

      expect(fields[:price]).to eq({ type: :float })
      expect(fields[:quantity]).to eq({ type: :integer })
      expect(fields[:category]).to eq({ type: :string })
    end

    it "excludes internal analyzer metadata" do
      form_schema = result.state[:input_form_schema]

      expect(form_schema[:items]).not_to have_key(:domain)
      expect(form_schema[:items]).not_to have_key(:container)
      expect(form_schema[:items]).not_to have_key(:children)
      expect(form_schema[:items]).not_to have_key(:access_mode)
      expect(form_schema[:items]).not_to have_key(:child_steps)
      expect(form_schema[:items]).not_to have_key(:define_index)
    end
  end

  describe "nested arrays" do
    let(:nested_schema) do
      Kumi::Core::RubyParser::Dsl.build_syntax_tree do
        input do
          array :regions do
            hash :region do
              array :offices do
                hash :office do
                  string :name
                  float :budget
                end
              end
            end
          end
        end

        value :total, 0.0
      end
    end

    let(:nested_result) { Kumi::Analyzer.analyze!(nested_schema) }

    it "handles deeply nested arrays and objects" do
      form_schema = nested_result.state[:input_form_schema]

      expect(form_schema[:regions][:type]).to eq(:array)
      expect(form_schema[:regions][:element][:type]).to eq(:object)

      offices = form_schema[:regions][:element][:fields][:offices]
      expect(offices[:type]).to eq(:array)
      expect(offices[:element][:type]).to eq(:object)

      office_fields = offices[:element][:fields]
      expect(office_fields[:name]).to eq({ type: :string })
      expect(office_fields[:budget]).to eq({ type: :float })
    end
  end

  describe "simple scalar inputs" do
    let(:scalar_schema) do
      Kumi::Core::RubyParser::Dsl.build_syntax_tree do
        input do
          string :username
          integer :age
          boolean :active
        end

        value :greeting, ""
      end
    end

    let(:scalar_result) { Kumi::Analyzer.analyze!(scalar_schema) }

    it "handles all scalar types" do
      form_schema = scalar_result.state[:input_form_schema]

      expect(form_schema[:username]).to eq({ type: :string })
      expect(form_schema[:age]).to eq({ type: :integer })
      expect(form_schema[:active]).to eq({ type: :boolean })
    end
  end

  describe "empty inputs" do
    let(:empty_schema) do
      Kumi::Core::RubyParser::Dsl.build_syntax_tree do
        value :result, 42
      end
    end

    let(:empty_result) { Kumi::Analyzer.analyze!(empty_schema) }

    it "handles schemas with no inputs" do
      form_schema = empty_result.state[:input_form_schema]

      expect(form_schema).to eq({})
    end
  end
end
