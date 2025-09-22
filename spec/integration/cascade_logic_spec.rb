# frozen_string_literal: true

RSpec.describe "Kumi Cascade Logic" do
  let(:syntax_tree) do
    Kumi::Core::RubyParser::Dsl.build_syntax_tree do
      input do
        key :role, type: Kumi::Core::Types::STRING
      end

      # -- Base Traits --
      trait :is_staff, input.role, :==, "staff"
      trait :is_admin, input.role, :==, "admin"
      trait :is_guest, input.role, :==, "guest"

      # -- Attribute with Cascade Logic --
      value :permission_level do
        on_any is_staff, is_admin, "Full Access" # [cite: 5]
        on_none is_staff, is_admin, "Read-Only" # [cite: 6]
        base "No Access" # [cite: 7]
      end
    end
  end
end
