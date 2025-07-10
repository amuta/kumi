# frozen_string_literal: true

RSpec.describe "Kumi Cascade Logic" do
  let(:syntax_tree) do
    Kumi::Parser::Dsl.build_sytax_tree do
      # -- Base Predicates --
      predicate :is_staff, key(:role), :==, "staff"
      predicate :is_admin, key(:role), :==, "admin"
      predicate :is_guest, key(:role), :==, "guest"

      # -- Attribute with Cascade Logic --
      value :permission_level do
        on_any :is_staff, :is_admin, "Full Access" # [cite: 5]
        on_none :is_staff, :is_admin, "Read-Only" # [cite: 6]
        base "No Access" # [cite: 7]
      end
    end
  end

  let(:executable_schema) do
    analyzer_result = Kumi::Analyzer.analyze!(syntax_tree)
    Kumi::Compiler.compile(syntax_tree, analyzer: analyzer_result)
  end

  context "when evaluating 'on_any'" do
    it "resolves to 'Full Access' for staff" do
      result = executable_schema.evaluate(role: "staff")
      expect(result[:permission_level]).to eq("Full Access")
    end

    it "resolves to 'Full Access' for admin" do
      result = executable_schema.evaluate(role: "admin")
      expect(result[:permission_level]).to eq("Full Access")
    end
  end

  context "when evaluating 'on_none'" do
    it "resolves to 'Read-Only' for guests" do
      result = executable_schema.evaluate(role: "guest")
      expect(result[:permission_level]).to eq("Read-Only")
    end

    it "resolves to 'Read-Only' for any other role" do
      result = executable_schema.evaluate(role: "user")
      expect(result[:permission_level]).to eq("Read-Only")
    end
  end
end
