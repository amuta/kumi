# frozen_string_literal: true

RSpec.describe "PackTestHelper" do
  include PackTestHelper

  it "generates pack from schema text" do
    schema_txt = <<~SCHEMA
      schema do
        input do
          integer :x
        end
        
        value :result, input.x + 1
      end
    SCHEMA

    pack = pack_for(schema_txt)
    
    expect(pack).to be_a(Hash)
    expect(pack["module_id"]).to be_a(String)
    expect(pack["plan"]).to be_a(Hash)
    expect(pack["inputs"]).to be_an(Array)
    expect(pack["declarations"]).to be_a(Hash)
  end

  it "supports multiple targets" do
    schema_txt = <<~SCHEMA
      schema do
        input do
          integer :x
        end
        
        value :result, input.x + 1
      end
    SCHEMA

    pack = pack_for(schema_txt, targets: %w[ruby])
    expect(pack["bindings"]).to have_key("ruby")
  end
end