# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # Planner: ingest raw IR, emit structured plans.
      #
      # Bundle per decl includes:
      #  - axis_carriers
      #  - site_schedule
      #  - reduce_plans_by_id  { id => ReducePlan }  (objects with placement)
      #  - inlining_policy (shared)
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
          :axis_carriers,      # AxisCarrierPlan
          :site_schedule,      # SiteSchedule
          :reduce_plans_by_id, # { Integer => ReducePlan }  (objects)
          keyword_init: true
        )

        class << self
          def from_ir(ir_hash)
            mod       = parse_module(ir_hash)
            access    = AccessPlan.new(mod.inputs)
            inlining  = InliningPolicy.build(module_spec: mod)

            per_decl = {}
            mod.decls.each_value do |decl|
              schedule = SiteSchedule.build(decl: decl)
              reduce_plans = build_reduce_plans(decl, schedule, access)

              reduce_axes_needed = []
              if decl.axes.empty? && !reduce_plans.empty?
                unique_reduce_axes = reduce_plans.values.map(&:axis).uniq
                reduce_axes_needed = unique_reduce_axes if unique_reduce_axes.size == 1
              end
              all_computation_axes = (decl.axes + reduce_axes_needed).uniq
              carriers = AxisCarrierPlan.build(decl_axes: all_computation_axes, access_plan: access)


              per_decl[decl.name] = PerDecl.new(
                decl: decl,
                axis_carriers: carriers,
                site_schedule: schedule,
                reduce_plans_by_id: reduce_plans
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

          # --- IR parsing into typed structs ---

          def parse_module(ir)
            inputs_array = ir.dig("analysis", "inputs") || []
            inputs = inputs_array.map { |h| parse_input(h) }
            decls  = {}
            (ir["declarations"] || {}).each do |name, d|
              decls[name.to_sym] = parse_decl(name, d)
            end
            Kumi::Codegen::Planning::ModuleSpec.new(
              version:  ir["version"],
              modname:  ir["module"],
              decls:    decls,
              inputs:   inputs,
              defaults: ir.dig("analysis", "defaults") || {}
            )
          end

          def parse_input(h)
            loops = h["navigation_steps"].map do |l|
              {
                path_fqn:     l["path_fqn"],
                loop_idx: l["loop_idx"],
                key: l["key"]
              }
            end

            Kumi::Codegen::Planning::InputSpec.new(
              path_fqn:       h["path_fqn"],
              navigation_steps: loops,
            )
          end

          def parse_decl(name, d)
            ops = Array(d["operations"]).map { |o| parse_op(o) }
            result_op = ops.find { |op| op.id == d["result"] }
            axes = if d["axes"] && !d["axes"].empty?
                     Array(d["axes"]).map(&:to_sym)
                   else
                     raise "Decl #{name} missing explicit axes and no result op found" unless result_op
                     raise "Decl #{name} result op missing stamp axes" unless result_op.stamp_axes
                     Array(result_op.stamp_axes).map(&:to_sym)
                   end.freeze

            Kumi::Codegen::Planning::DeclSpec.new(
              name:        name.to_s.to_sym,
              axes:        axes,
              parameters:  Array(d["parameters"]),
              ops:         ops,
              result_id:   d["result"]
            )
          end

          def parse_op(o)
            kind  = o["op"].to_s.downcase.to_sym
            attrs = (o["attrs"] || {}).dup

            axes_for_op = Array(o.dig("stamp", "axes")).map(&:to_sym)

            Kumi::Codegen::Planning::OpSpec.new(
              id:         o["id"],
              kind:       kind,
              args:       o["args"],
              stamp_axes: axes_for_op,
              dtype:      (o.dig("stamp", "dtype") || "any").to_s.to_sym,
              attrs:      attrs
            )
          end

          def meet_axes_of(list_of_axes)
            return [] if list_of_axes.empty?
            list_of_axes.max_by(&:length) || []
          end

          private

          def build_reduce_plans(decl, schedule, access)
            reduce_ops = decl.ops.select { |op| op.kind == :reduce }
            return {} if reduce_ops.empty?

            # Build the op_id -> depth map once.
            depth_of = {}
            schedule.instance_variable_get(:@by_depth).each do |d, ops|
              ops.each { |op| depth_of[op.id] = d }
            end

            # Build a map of all reduce op IDs for the 'nested' check.
            reduce_op_ids = Set.new(reduce_ops.map(&:id))

            # Create the final ReducePlan objects in a single pass.
            reduce_ops.to_h do |op|
              # Part 1: Logic from the old `ReducePlan.from_op` and `build_reduce_plans`
              plan = ReducePlan.from_op(op: op, access_plan: access)

              # Part 2: Logic from the old `finalize_reduce_plans`
              arg = plan.arg_id
              res_d = plan.result_depth
              nested = reduce_op_ids.include?(arg)
              arg_d = depth_of.fetch(arg)
              
              contrib, reset, bind = if nested
                [res_d, res_d, res_d]
              else
                [arg_d, res_d, res_d]
              end

              # The `consumed_by_parent` check can be simplified and done here.
              # If this op is NOT the final result of the whole declaration, it has a consumer.
              is_final_result = (op.id == decl.result_id)
              if is_final_result && res_d == 0
                bind = -1
              end
              
              final_plan = plan.with_placement(
                contrib_depth: contrib,
                reset_depth:   reset,
                bind_depth:    bind,
                nested:        nested
              )

              [op.id, final_plan]
            end
          end
        end
      end
    end
  end
end
