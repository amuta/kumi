# frozen_string_literal: true

# TODO: REWRITE THIS WITH NEW PUBLIC API INTERFACE
RSpec.describe Kumi::Schema do
  let(:test_class) do
    Class.new do
      extend Kumi::Schema
    end
  end

  describe "module extension" do
    xit "adds schema methods to extended class" do
      expect(test_class).to respond_to(:schema)
      expect(test_class).to respond_to(:from)
      expect(test_class).to respond_to(:explain)
      expect(test_class).to respond_to(:schema_metadata)
    end

    xit "adds instance variable readers" do
      expect(test_class).to respond_to(:__syntax_tree__)
      expect(test_class).to respond_to(:__analyzer_result__)
      expect(test_class).to respond_to(:__executable__)
    end
  end

  describe "#schema" do
    xit "handles empty schema block" do
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

      xit "returns nil" do
        expect(valid_schema).to be_nil
      end

      xit "sets internal instance variables" do
        valid_schema

        expect(test_class.instance_variable_get(:@__syntax_tree__)).not_to be_nil
        expect(test_class.instance_variable_get(:@__analyzer_result__)).not_to be_nil
        expect(test_class.instance_variable_get(:@__executable__)).not_to be_nil
      end

      xit "freezes the created objects" do
        valid_schema

        expect(test_class.instance_variable_get(:@__syntax_tree__)).to be_frozen
        expect(test_class.instance_variable_get(:@__analyzer_result__)).to be_frozen
        expect(test_class.instance_variable_get(:@__executable__)).to be_frozen
      end

      xit "creates Runtime::Executable as compiled schema" do
        valid_schema

        compiled_schema = test_class.instance_variable_get(:@__executable__)
        expect(compiled_schema).to be_a(Kumi::Runtime::Executable)
      end
    end
  end

  describe "#from" do
    context "when no schema is defined" do
      xit "raises error" do
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

      xit "creates runtime run instance with valid input" do
        instance = test_class.from(age: 25)

        expect(instance).not_to be_nil
        expect(instance).to be_a(Kumi::Runtime::Run)
        expect(instance).to respond_to(:[])
        expect(instance).to respond_to(:get)
      end

      xit "allows accessing computed values through the instance" do
        instance = test_class.from(age: 25)

        expect(instance[:adult]).to be true
        expect(instance.adult).to be true
      end

      xit "validates input and raises error for invalid data" do
        expect { test_class.from(age: "invalid") }.to raise_error
      end

      xit "handles missing fields" do
        expect { test_class.from({}) }.not_to raise_error
      end
    end
  end

  describe "#explain" do
    context "when no schema is defined" do
      xit "raises error" do
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

      xit "explains computation without error" do
        expect { test_class.explain({ age: 25 }, :adult) }.to output(/adult = input.age >= 18 = 25 >= 18 => true/).to_stdout
      end

      xit "validates input before explaining" do
        expect { test_class.explain({ age: "invalid" }, :adult) }.to raise_error
      end
    end
  end

  describe "#schema_metadata" do
    context "when no schema is defined" do
      xit "raises error" do
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

      xit "returns schema metadata object" do
        metadata = test_class.schema_metadata
        expect(metadata).to be_a(Kumi::SchemaMetadata)
      end

      xit "memoizes metadata object" do
        metadata1 = test_class.schema_metadata
        metadata2 = test_class.schema_metadata

        expect(metadata1).to be(metadata2)
      end
    end
  end
end
