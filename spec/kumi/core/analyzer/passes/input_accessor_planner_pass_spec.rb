# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::AccessPlannerPass do
  subject { described_class.new(mock_schema, state) }

  let(:mock_schema) { double("schema") }
  let(:input_metadata) do
    {
      user: {
        type: :hash,
        children: {
          name: { type: :string },
          age: { type: :integer }
        }
      },
      items: {
        type: :array,
        children: {
          price: { type: :float }
        }
      }
    }
  end
  let(:state) { Kumi::Core::Analyzer::AnalysisState.new(inputs: input_metadata) }

  it "creates access plans from input metadata" do
    errors = []
    result_state = subject.run(errors)

    expect(errors).to be_empty
    expect(result_state[:input_access_plans]).to be_a(Hash)
    expect(result_state[:input_access_plans]).to have_key("user")
    expect(result_state[:input_access_plans]).to have_key("user.name")
    expect(result_state[:input_access_plans]).to have_key("items")
    expect(result_state[:input_access_plans]).to have_key("items.price")
  end

  it "creates correct operation plans" do
    errors = []
    result_state = subject.run(errors)

    user_plan = result_state[:input_access_plans]["user"]
    expect(user_plan).to have_key(:element)
    expect(user_plan[:element][:operations]).to eq([{ type: :enter_hash, key: :user }])

    items_price_plan = result_state[:input_access_plans]["items.price"]
    expected_operations = [
      { type: :enter_hash, key: :items },
      { type: :enter_array },
      { type: :enter_hash, key: :price }
    ]
    expect(items_price_plan[:element][:operations]).to eq(expected_operations)
  end
end
