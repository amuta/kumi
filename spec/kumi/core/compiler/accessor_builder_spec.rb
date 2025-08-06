# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/accessor_builder"

RSpec.describe Kumi::Core::Compiler::AccessorBuilder do
  it "builds lambda functions from access plans" do
    access_plans = {
      "name" => {
        structure: { type: :structure, path: [:name], operations: [{ type: :fetch, key: :name }] }
      }
    }

    accessors = described_class.build(access_plans)

    expect(accessors).to have_key("name:structure")
    expect(accessors["name:structure"]).to be_a(Proc)
    
    # Test the accessor
    result = accessors["name:structure"].call({ "name" => "John" })
    expect(result).to eq("John")
  end

  it "builds element accessor that maps over arrays" do
    access_plans = {
      "items.price" => {
        element: { 
          type: :element, 
          path: [:items, :price], 
          operations: [
            { type: :fetch, key: :items },
            { type: :enter_array, access_mode: :object },
            { type: :fetch, key: :price }
          ]
        }
      }
    }

    accessors = described_class.build(access_plans)
    
    test_data = { "items" => [{ "price" => 10.0 }, { "price" => 20.0 }] }
    result = accessors["items.price:element"].call(test_data)
    expect(result).to eq([10.0, 20.0])
  end

  it "builds flattened accessor that flattens arrays" do
    access_plans = {
      "matrix" => {
        flattened: { 
          type: :flattened, 
          path: [:matrix], 
          operations: [
            { type: :fetch, key: :matrix },
            { type: :flatten }
          ]
        }
      }
    }

    accessors = described_class.build(access_plans)
    
    test_data = { "matrix" => [[1, 2], [3, 4]] }
    result = accessors["matrix:flattened"].call(test_data)
    expect(result).to eq([1, 2, 3, 4])
  end
end