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

      # Deterministic JSON (flat, with strings and simple arrays)
      def to_json(bundle)
        out = { "declarations" => {} }

        bundle.by_decl.each do |decl_name, per_decl|
          decl     = per_decl.decl
          schedule = per_decl.site_schedule
          carriers = per_decl.axis_carriers
          reduces  = per_decl.reduce_plans_by_id # { id => ReducePlan }

          out["declarations"][decl_name.to_s] = {
            "axes" => decl.axes.map(&:to_s),
            "parameters" => decl.parameters,
            "site_schedule" => {
              "max_depth" => schedule.max_depth,
              "hoisted_scalars" => schedule.hoisted_scalars.map { |op| { "id" => op.id, "kind" => op.kind.to_s } },
              "root_reduces"    => schedule.root_reduces.map    { |op| { "id" => op.id, "kind" => op.kind.to_s } },
              "by_depth" => (0..schedule.max_depth).map do |d|
                { "depth" => d, "ops" => schedule.ops_at_depth(d).map { |op| { "id" => op.id, "kind" => op.kind.to_s } } }
              end
            },
            "axis_carriers" => carriers.to_entries.map { |e| { "axis" => e[:axis].to_s, "via_path" => e[:via_path] } },
            # Canonical reduce plans list; PackView will hand this to DeclContext
            "reduce_plans" => reduces.values.map(&:to_entry).map { |e|
              {
                "op_id"         => e[:op_id],
                "axis"          => e[:axis].to_s,
                "arg_id"        => e[:arg_id],
                "reducer_fn"    => e[:reducer_fn],
                "result_depth"  => e[:result_depth],
                "reset_depth"   => e[:reset_depth],
                "contrib_depth" => e[:contrib_depth],
                "bind_depth"    => e[:bind_depth],
                "nested"        => !!e[:nested],
                "via_path"      => e[:via_path]
              }
            },
            "inlining_decisions" => {}
          }

          # Per-LoadDeclaration inlining decisions (by op id)
          decl.ops.select { |op| op.kind == :loaddeclaration }.each do |op|
            dep_name = op.args.first
            dep_decl = bundle.by_decl[dep_name.to_sym]&.decl
            next unless dep_decl
            decision = bundle.inlining_policy.decision(
              producer_decl: dep_decl,
              consumer_use_site_axes: op.stamp_axes
            )
            out["declarations"][decl_name.to_s]["inlining_decisions"]["op_#{op.id}"] = {
              "producer" => dep_name.to_s,
              "decision" => decision.to_s,
              "use_site_axes" => op.stamp_axes.map(&:to_s)
            }
          end
        end

        out
      end
    end
  end
end
