# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Concat — variadic arity behavior" do
  let(:schema_mod) do
    Module.new do
      extend Kumi::Schema
      schema do
        input do
          array :names do
            string :value
          end
        end
        value :zero,    fn(:concat)                         # => ""
        value :one_s,   fn(:concat, "x")                    # => "x"
        value :many_s,  fn(:concat, "a","-","b","-","c")    # => "a-b-c"
        value :vec_id,  fn(:concat, input.names.value)      # => same vector
        value :vec_mix, fn(:concat, "[", input.names.value, "]")
      end
    end
  end

  it { expect(schema_mod.from(names: []).zero).to eq("") }
  it { expect(schema_mod.from(names: []).one_s).to eq("x") }
  it { expect(schema_mod.from(names: []).many_s).to eq("a-b-c") }
  
  it "identity for a single vector arg" do
    s = schema_mod.from(names:[{value:"bob"},{value:"carol"}])
    expect(s.vec_id).to eq(["bob","carol"])
    expect(s.vec_mix).to eq(["[bob]","[carol]"])
  end
end