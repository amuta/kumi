# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Dual Mode Injection" do
  let(:simple_schema) do
    Module.new do
      extend Kumi::Schema

      schema do
        input do
          integer :age
        end

        trait :adult, (input.age >= 18)
        value :status, "Adult"
      end
    end
  end

  it "injects dual mode behavior in specs automatically" do
    test_data = { age: 25 }
    runner = simple_schema.from(test_data)

    # Verify we get a DualRunner instance, not a regular SchemaInstance
    expect(runner).to be_a(DualRunner)
    expect(runner[:adult]).to be(true)
    expect(runner[:status]).to eq("Adult")
  end

  it "from method has clean signature without dual_mode parameter" do
    method = simple_schema.method(:from)

    # Verify the method only accepts one parameter (context)
    expect(method.arity).to eq(1)
    expect(method.parameters).to eq([%i[req context]])
  end
end
