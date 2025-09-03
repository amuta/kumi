# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::ConstPlan do
  describe ".run" do
    context "pack-driven const placement (not heuristics)" do
      let(:ctx) do
        {
          ops: [
            {"id" => 0, "op" => "Const", "args" => [1]},
            {"id" => 2, "op" => "Const", "args" => [10]},
            {"id" => 5, "op" => "Const", "args" => [2]}
          ],
          site_schedule: {
            "hoisted_scalars" => [
              {"id" => 0, "kind" => "const"},
              {"id" => 2, "kind" => "const"}
            ]
          }
        }
      end
      
      it "puts hoisted consts in prelude" do
        result = described_class.run(ctx)
        
        expect(result[:prelude]).to contain_exactly(
          {name: "c0", value: 1},
          {name: "c2", value: 10}
        )
      end
      
      it "marks non-hoisted consts for inlining" do
        result = described_class.run(ctx)
        
        expect(result[:inline_ids]).to contain_exactly(5)
      end
      
      it "reads pack data, not usage count heuristics" do
        # This test ensures we follow hoisted_scalars, not usage patterns
        expect(described_class).not_to receive(:count_usages)
        
        described_class.run(ctx)
      end
    end
  end
end