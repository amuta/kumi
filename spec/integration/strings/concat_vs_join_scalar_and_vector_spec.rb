# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Concat vs Join — scalar & vector basics" do
  let(:schema_mod) do
    Module.new do
      extend Kumi::Schema
      schema do
        input do
          array :people do
            string :name
            integer :age
          end
          array :tags do
            string :value
          end
        end

        # element-wise formatting (zip/broadcast)
        value :labels, fn(:concat, input.people.name, " (", input.people.age, ")")

        # reducer: collapse the tags axis
        value :tags_csv, fn(:join, input.tags.value, ", ")
      end
    end
  end

  it "concat: zip vector + broadcast scalars → preserves axis" do
    s = schema_mod.from(people: [{name:"Bob",age:25},{name:"Carol",age:35}])
    expect(s.labels).to eq(["Bob (25)", "Carol (35)"])
  end

  it "join: reduces a vector to a single string" do
    s = schema_mod.from(tags: [{value:"a"},{value:"b"},{value:"c"}])
    expect(s.tags_csv).to eq("a, b, c")
  end
end