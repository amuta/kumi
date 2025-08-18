# frozen_string_literal: true
require "spec_helper"

RSpec.describe "String concat basic functionality" do
  let(:concat_schema) do
    Module.new do
      extend Kumi::Schema
      schema do
        input do
          array :people do
            string :name
            integer :age
          end
        end

        # element-wise formatting (zip/broadcast)
        value :labels, fn(:concat, input.people.name, " (", input.people.age, ")")
      end
    end
  end

  let(:join_schema) do  
    Module.new do
      extend Kumi::Schema
      schema do
        input do
          array :tags do
            string :value
          end
        end

        # reducer: collapse the tags axis  
        value :tags_csv, fn("string.join", input.tags.value, ", ")
      end
    end
  end

  it "concat: zip vector + broadcast scalars → preserves axis" do
    s = concat_schema.from(people: [{name:"Bob",age:25},{name:"Carol",age:35}])
    expect(s.labels).to eq(["Bob (25)", "Carol (35)"])
  end

  it "join: reduces a vector to a single string" do
    s = join_schema.from(tags: [{value:"a"},{value:"b"},{value:"c"}])
    expect(s.tags_csv).to eq("a, b, c")
  end
end