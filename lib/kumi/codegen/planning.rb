# frozen_string_literal: true

require_relative "planning/types"
require_relative "planning/access_plan"
require_relative "planning/axis_carrier_plan"
require_relative "planning/site_schedule"
require_relative "planning/reduce_plan"
require_relative "planning/inlining_policy"
require_relative "planning/planner"

module Kumi
  module Codegen
    module Planning
      VERSION = "0.1"

      module_function

      def from_ir(ir_hash)
        Planner.from_ir(ir_hash)
      end

      def to_json(bundle)
        output = {
          "declarations" => {}
        }

        bundle.by_decl.each do |decl_name, per_decl|
          decl = per_decl.decl
          schedule = per_decl.site_schedule
          carriers = per_decl.axis_carriers
          reduces = per_decl.reduce_plans_by_id

          output["declarations"][decl_name.to_s] = {
            "axes" => decl.axes.map(&:to_s),
            "parameters" => decl.parameters,
            "site_schedule" => {
              "max_depth" => schedule.max_depth,
              "hoisted_scalars" => schedule.hoisted_scalars.map { |op| { "id" => op.id, "kind" => op.kind.to_s } },
              "root_reduces" => schedule.root_reduces.map { |op| { "id" => op.id, "kind" => op.kind.to_s } },
              "by_depth" => (0..schedule.max_depth).map do |d|
                {
                  "depth" => d,
                  "ops" => schedule.ops_at_depth(d).map { |op| { "id" => op.id, "kind" => op.kind.to_s } }
                }
              end
            },
            "axis_carriers" => carriers.to_entries.map do |entry|
              {
                "axis" => entry[:axis].to_s,
                "via_path" => entry[:via_path]
              }
            end,
            "reduce_plans" => reduces.values.map(&:to_entry).map do |entry|
              {
                "op_id" => entry[:op_id],
                "axis" => entry[:axis].to_s,
                "result_depth" => entry[:result_depth],
                "arg_id" => entry[:arg_id],
                "reducer_fn" => entry[:reducer_fn],
                "via_path" => entry[:via_path]
              }
            end,
            "inlining_decisions" => {}
          }

          # Add per-operation inlining decisions for LoadDeclaration ops
          decl.ops.select { |op| op.kind == :loaddeclaration }.each do |op|
            dep_name = op.args.first
            dep_decl = bundle.by_decl[dep_name.to_sym]&.decl
            if dep_decl
              # Use the specific use site axes of this LoadDeclaration op
              decision = bundle.inlining_policy.decision(
                producer_decl: dep_decl, 
                consumer_use_site_axes: op.stamp_axes
              )
              # Store decision per operation ID for precise codegen control
              output["declarations"][decl_name.to_s]["inlining_decisions"]["op_#{op.id}"] = {
                "producer" => dep_name.to_s,
                "decision" => decision.to_s,
                "use_site_axes" => op.stamp_axes.map(&:to_s)
              }
            end
          end
        end

        output
      end
    end
  end
end