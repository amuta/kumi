# frozen_string_literal: true

RSpec.describe Kumi::Core::Compiler::AccessPlanner do
  context "for object-mode paths" do
    let(:input_metadata) do
      {
        departments: {
          type: :array,
          access_mode: :object,
          children: {
            name: { type: :string },
            teams: {
              type: :array,
              access_mode: :object,
              children: {
                team_name: { type: :string }
              }
            }
          }
        }
      }
    end

    it "generates a sequence of enter_hash and enter_array operations" do
      plans = described_class.plan(input_metadata)
      # operations = plans.dig("departments.teams.team_name", :element, :operations)
      operations = plans["departments.teams.team_name"][0][:operations]

      expected_operations = [{ type: :enter_hash, key: "departments", on_missing: :error, key_policy: :indifferent },
                             { type: :enter_array, on_missing: :error },
                             { type: :enter_hash, key: "teams", on_missing: :error, key_policy: :indifferent },
                             { type: :enter_array, on_missing: :error },
                             { type: :enter_hash, key: "team_name", on_missing: :error, key_policy: :indifferent }]

      expect(operations).to eq(expected_operations)
    end
  end
end
