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
            kind = o["op"].to_s.downcase.to_sym

            # Pull attrs up front so we can tack metadata on for tuples
            attrs = (o["attrs"] || {}).dup

            if kind == :constructtuple
              elem_stamps = Array(o["elem_stamps"]).map { |st| Array(st["axes"]).map(&:to_sym) }
              meet_axes = meet_axes_of(elem_stamps)

              # Compute per-arg suffix axes (what remains under the tuple)
              tuple_args = elem_stamps.each_with_index.map do |axes, idx|
                # common prefix length
                k = 0
                while k < meet_axes.length && k < axes.length && axes[k] == meet_axes[k]
                  k += 1
                end
                { 
                  arg_index: idx, 
                  suffix_axes: axes[k..] || [], 
                  materialize_full: (axes.length > meet_axes.length) 
                }
              end

              attrs["elem_stamps"] = elem_stamps
              attrs["tuple_args"] = tuple_args
              axes_for_op = meet_axes
            else
              axes_for_op = Array(o.dig("stamp", "axes")).map(&:to_sym)
            end

            Kumi::Codegen::Planning::OpSpec.new(
              id: o["id"],
              kind: kind,
              args: o["args"],
              stamp_axes: axes_for_op,
              dtype: (o.dig("stamp", "dtype") || "any").to_s.to_sym,
              attrs: attrs
            )
          end

          # Helper to compute longest common prefix of axis lists
          def meet_axes_of(list_of_axes)
            return [] if list_of_axes.empty?

            list_of_axes.reduce do |acc, axes|
              # longest common prefix
              i = 0
              while i < acc.length && i < axes.length && acc[i] == axes[i]
                i += 1
              end
              acc.take(i)
            end
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
