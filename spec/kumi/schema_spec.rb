# frozen_string_literal: true

RSpec.describe Kumi::Schema do
  let(:test_class) do
    Class.new do
      extend Kumi::Schema
    end
  end

  describe "module extension" do
    it "adds schema methods to extended class" do
      expect(test_class).to respond_to(:schema)
      expect(test_class).to respond_to(:from)
      expect(test_class).to respond_to(:explain)
      expect(test_class).to respond_to(:schema_metadata)
    end

    it "adds instance variable readers" do
      expect(test_class).to respond_to(:__syntax_tree__)
      expect(test_class).to respond_to(:__analyzer_result__)
      expect(test_class).to respond_to(:__compiled_schema__)
    end
  end

  describe "Inspector struct" do
    let(:inspector) { Kumi::Schema::Inspector.new("tree", "result", "schema") }

    it "creates inspector with correct attributes" do
      expect(inspector.syntax_tree).to eq("tree")
      expect(inspector.analyzer_result).to eq("result")
      expect(inspector.compiled_schema).to eq("schema")
    end

    it "has custom inspect method" do
      expect(inspector.inspect).to include("Inspector")
      expect(inspector.inspect).to include("syntax_tree")
      expect(inspector.inspect).to include("analyzer_result")
    end
  end

  describe "#schema" do
    it "handles empty schema block" do
      expect { test_class.schema {} }.not_to raise_error
    end

    context "with valid schema" do
      let(:valid_schema) do
        test_class.schema do
          input do
            integer :age
          end
          
          trait :adult, (input.age >= 18)
        end
      end

      it "returns inspector object" do
        expect(valid_schema).to be_a(Kumi::Schema::Inspector)
      end

      it "sets internal instance variables" do
        valid_schema
        
        expect(test_class.instance_variable_get(:@__syntax_tree__)).not_to be_nil
        expect(test_class.instance_variable_get(:@__analyzer_result__)).not_to be_nil
        expect(test_class.instance_variable_get(:@__compiled_schema__)).not_to be_nil
      end

      it "freezes the created objects" do
        valid_schema
        
        expect(test_class.instance_variable_get(:@__syntax_tree__)).to be_frozen
        expect(test_class.instance_variable_get(:@__analyzer_result__)).to be_frozen
        expect(test_class.instance_variable_get(:@__compiled_schema__)).to be_frozen
      end
    end
  end

  describe "#from" do
    context "when no schema is defined" do
      it "raises error" do
        expect { test_class.from({}) }.to raise_error("No schema defined")
      end
    end

    context "with defined schema" do
      before do
        test_class.schema do
          input do
            integer :age
          end
          
          trait :adult, (input.age >= 18)
        end
      end

      it "creates schema instance with valid input" do
        instance = test_class.from(age: 25)
        
        expect(instance).not_to be_nil
        expect(instance).to respond_to(:fetch)
      end

      it "validates input and raises error for invalid data" do
        expect { test_class.from(age: "invalid") }.to raise_error
      end

      it "handles missing fields" do
        expect { test_class.from({}) }.not_to raise_error
      end
    end
  end

  describe "#explain" do
    context "when no schema is defined" do
      it "raises error" do
        expect { test_class.explain({}, :test) }.to raise_error("No schema defined")
      end
    end

    context "with defined schema" do
      before do
        test_class.schema do
          input do
            integer :age
          end
          
          trait :adult, (input.age >= 18)
          value :status, adult ? "Adult" : "Minor"
        end
      end

      it "explains computation without error" do
        expect { test_class.explain({ age: 25 }, :adult) }.not_to raise_error
      end

      it "returns nil" do
        result = test_class.explain({ age: 25 }, :adult)
        expect(result).to be_nil
      end

      it "validates input before explaining" do
        expect { test_class.explain({ age: "invalid" }, :adult) }.to raise_error
      end
    end
  end

  describe "#schema_metadata" do
    context "when no schema is defined" do
      it "raises error" do
        expect { test_class.schema_metadata }.to raise_error("No schema defined")
      end
    end

    context "with defined schema" do
      before do
        test_class.schema do
          input do
            integer :age
          end
          
          trait :adult, (input.age >= 18)
        end
      end

      it "returns schema metadata object" do
        metadata = test_class.schema_metadata
        expect(metadata).to be_a(Kumi::SchemaMetadata)
      end

      it "memoizes metadata object" do
        metadata1 = test_class.schema_metadata
        metadata2 = test_class.schema_metadata
        
        expect(metadata1).to be(metadata2)
      end
    end
  end
end