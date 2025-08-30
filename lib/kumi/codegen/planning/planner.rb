# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # Planner is the facade: ingest raw IR Hash, emit structured plans.
      #
      # Interface:
      #   .from_ir(ir_hash) -> Planner::Bundle
      #   Bundle#decl(name) -> PerDecl bundle with:
      #     - access_plan (shared)
      #     - axis_carriers
      #     - site_schedule
      #     - reduce_plans_by_id
      #     - inlining_policy (shared)
      class Planner
        Bundle = Struct.new(
          :module_spec,
          :access_plan,
          :inlining_policy,
          :by_decl, # {Symbol => PerDecl}
          keyword_init: true
        )

        PerDecl = Struct.new(
          :decl,
          :axis_carriers,   # AxisCarrierPlan
          :site_schedule,   # SiteSchedule
          :reduce_plans_by_id, # { Integer => ReducePlan }
          keyword_init: true
        )

        class << self
          def from_ir(ir_hash)
            mod = parse_module(ir_hash)
            access = AccessPlan.new(mod.inputs)
            inlining = InliningPolicy.build(module_spec: mod)

            per_decl = {}
            mod.decls.each_value do |decl|
              # Build carriers only for outer declaration axes
              carriers = AxisCarrierPlan.build(decl_axes: decl.axes, access_plan: access)
              schedule = SiteSchedule.build(decl: decl)
              reduces  = build_reduce_plans(decl, access)

              per_decl[decl.name] = PerDecl.new(
                decl: decl,
                axis_carriers: carriers,
                site_schedule: schedule,
                reduce_plans_by_id: reduces
              )
            end

            Bundle.new(
              module_spec: mod,
              access_plan: access,
              inlining_policy: inlining,
              by_decl: per_decl
            )
          end

          private

          # --- IR parsing into typed structs (minimal, straight from your schema) ---

          def parse_module(ir)
            inputs = Array(ir.dig("analysis", "inputs")).map { |h| parse_input(h, ir.dig("analysis", "defaults") || {}) }
            decls  = {}
            (ir["declarations"] || {}).each do |name, d|
              decls[name.to_sym] = parse_decl(name, d)
            end
            Kumi::Codegen::Planning::ModuleSpec.new(
              version: ir["version"],
              modname: ir["module"],
              decls: decls,
              inputs: inputs,
              defaults: ir.dig("analysis", "defaults") || {}
            )
          end

          def parse_input(h, defaults)
            Kumi::Codegen::Planning::InputSpec.new(
              path: Array(h["path"]).map(&:to_s),
              axes: Array(h["axes"]).map(&:to_sym),
              dtype: h["dtype"].to_s.to_sym,
              key_policy: (h["key_policy"] || defaults["key_policy"] || "indifferent").to_s.to_sym,
              on_missing: (h["on_missing"] || defaults["on_missing"] || "error").to_s.to_sym,
              chain: Array(h["chain"])
            )
          end

          def parse_decl(name, d)
            ops = Array(d["operations"]).map { |o| parse_op(o) }
            result_op = ops.find { |op| op.id == d["result"] }
            axes = if d["axes"] && !d["axes"].empty?
              Array(d["axes"]).map(&:to_sym)
            else
              result_op ? Array(result_op.stamp_axes) : []
            end.freeze
            
            Kumi::Codegen::Planning::DeclSpec.new(
              name: name.to_s.to_sym,
              axes: axes,
              parameters: Array(d["parameters"]),
              ops: ops,
              result_id: d["result"]
            )
          end

          def parse_op(o)
            Kumi::Codegen::Planning::OpSpec.new(
              id: o["id"],
              kind: o["op"].to_s.downcase.to_sym, # "LoadInput" -> :load_input
              args: o["args"],
              stamp_axes: Array(o.dig("stamp", "axes")).map(&:to_sym),
              dtype: (o.dig("stamp", "dtype") || "any").to_s.to_sym,
              attrs: o["attrs"] || {}
            )
          end

          def build_reduce_plans(decl, access)
            decl.ops
                .select { |op| op.kind == :reduce }
                .map { |op| [op.id, ReducePlan.from_op(op: op, access_plan: access)] }
                .to_h
          end
        end
      end
    end
  end
end
