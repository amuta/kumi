# frozen_string_literal: true

module Kumi
  module Codegen
    class Ruby
      class Planner
        DeclarationPlan = Struct.new(
          :name, :operations, :result_op_id, :parameters, :ops_by_id,
          keyword_init: true
        )

        def initialize(ir_data, binding_manifest)
          @ir_data = ir_data
          @binding_manifest = binding_manifest
          @binding_by_decl_op = {}
          binding_manifest["bindings"].each do |b|
            @binding_by_decl_op[[b["decl"], b["op"]]] = b
          end
        end

        def plan_all_declarations
          @ir_data["declarations"].map do |decl_name, decl_data|
            plan_declaration(decl_name, decl_data)
          end
        end

        private

        # L(op): logical axes by provenance
        def logical_axes_of(op_rec, ops_by_id)
          case op_rec["op"]
          when "Reduce"
            src_id = op_rec["args"][0]
            prev   = logical_axes_of(ops_by_id[src_id], ops_by_id)
            prev[0...-1]
          else
            (op_rec["stamp"] || {})["axes"] || []
          end
        end

        def plan_declaration(decl_name, decl)
          ops = decl["operations"]
          ops_by_id = {}
          ops.each { |op| ops_by_id[op["id"]] = op }

          scheduled = ops.map { |op| plan_op(decl_name, op, ops_by_id) }

          DeclarationPlan.new(
            name: decl_name,
            operations: scheduled,
            result_op_id: decl["result"],
            parameters: decl["parameters"],
            ops_by_id: ops_by_id
          )
        end

        def plan_op(decl_name, op, ops_by_id)
          binding = @binding_by_decl_op[[decl_name, op["id"]]]
          stamp   = op["stamp"] || { "axes" => [], "dtype" => "unknown" }

          case op["op"]
          when "Map", "Select"
            result_axes = stamp["axes"] || []
            arg_ids     = op["args"] || []

            arg_L = arg_ids.map { |id| logical_axes_of(ops_by_id[id], ops_by_id) }

            # validate prefix-only lineage
            arg_L.each_with_index do |axes, idx|
              unless result_axes[0, axes.length] == axes
                raise "Lineage/prefix violation in #{op['op']} op=#{op['id']} arg##{idx}: L=#{axes.inspect} vs R=#{result_axes.inspect}"
              end
            end

            driver_index = arg_L.find_index { |axes| axes.length == result_axes.length }
            raise "No driver found for #{op['op']} op=#{op['id']}" if driver_index.nil?

            masks = arg_L.map do |axes|
              r = axes.length
              Array.new(r, false) + Array.new(result_axes.length - r, true)
            end

            {
              id: op["id"],
              op_type: op["op"],
              args: arg_ids,
              stamp: stamp,
              attrs: op["attrs"] || {},
              binding: binding,
              driver_index: driver_index,
              masks: masks,
              result_axes: result_axes
            }
          when "Reduce"
            src_id = op["args"][0]
            src_L  = logical_axes_of(ops_by_id[src_id], ops_by_id)
            res_R  = stamp["axes"] || []
            unless src_L[0, res_R.length] == res_R && src_L.length == res_R.length + 1
              raise "Reduce shape mismatch op=#{op['id']}: L(src)=#{src_L.inspect}, R=#{res_R.inspect}"
            end

            {
              id: op["id"],
              op_type: "Reduce",
              args: op["args"] || [],
              stamp: stamp,
              attrs: op["attrs"] || {},
              binding: binding,
              result_axes: res_R # for emitter’s outer-loop rank
            }
          else
            {
              id: op["id"],
              op_type: op["op"],
              args: op["args"] || [],
              stamp: stamp,
              attrs: op["attrs"] || {},
              binding: binding
            }
          end
        end
      end
    end
  end
end
