# frozen_string_literal: true

require_relative "name_mangler"

module Kumi
  module Codegen
    module RubyV2
      class OpsEmitter
        def initialize(plan_decl_by_name:, chain_const_by_input_name:, ops_by_decl: {})
          @plans  = plan_decl_by_name
          @chains = chain_const_by_input_name
          @decls  = ops_by_decl
        end

        def emit_ops_subset(decl_name, decl_spec, only_ids:, reduce_chain: false)
          ops = Array(decl_spec.fetch("operations")).select { |o| only_ids.include?(o.fetch("id")) }
          ops.flat_map { |op| emit_one_op(decl_name, decl_spec, op, reduce_chain: reduce_chain) }
        end

        def emit_body_for_decl(decl_name, decl_spec, skip_ids:, reduce_chain: false)
          decl_ops = Array(decl_spec.fetch("operations")).reject { |o| skip_ids.include?(o.fetch("id")) }
          lines    = decl_ops.flat_map { |op| emit_one_op(decl_name, decl_spec, op, reduce_chain: reduce_chain) }

          result_var =
            if decl_spec.key?("result_op_id")
              NameMangler.tmp_for_op(decl_spec["result_op_id"])
            else
              NameMangler.tmp_for_op(decl_ops.last.fetch("id"))
            end

          [lines, result_var]
        end

        def emit_site_scalar_for_decl(prod_name:, prod_spec:, plan_decl:, chain_map:, scope_axes:, ns:, skip_reduce_ops: true)
          lines = []
          
          # Filter out Reduce operations if requested
          ops_to_process = prod_spec["operations"]
          if skip_reduce_ops
            ops_to_process = ops_to_process.reject { |op| op["op"] == "Reduce" }
          end

          ops_to_process.each do |op|
            id = NameMangler.tmp_for_op(op["id"], ns: ns)
            case op["op"]
            when "LoadInput"
              path = Array(op["args"]).first.join(".")
              const = chain_map.fetch(path)
              lines << "#{id} = __walk__(#{const}, input, cursors)"
            when "Const"
              # Skip if this constant is used directly in a Select
              select_op = ops_to_process.find { |o| o["op"] == "Select" && Array(o["args"]).include?(op["id"]) }
              unless select_op
                lines << "#{id} = #{JSON.generate(Array(op["args"]).first)}"
              end
            when "Map"
              fn = op["attrs"]["fn"]
              args = Array(op["args"]).map { |ref| NameMangler.tmp_for_op(ref, ns: ns) }.join(", ")
              lines << "#{id} = __call_kernel__(#{fn.inspect}, #{args})"
            when "Select"
              args = Array(op["args"])
              # Use inline substitution if available, otherwise use variable name
              a = (@inline_substitutions && @inline_substitutions[args[0]]) || NameMangler.tmp_for_op(args[0], ns: ns)
              # Look up the actual values for constants instead of using variables
              b_op = ops_to_process.find { |o| o["id"] == args[1] }
              c_op = ops_to_process.find { |o| o["id"] == args[2] }
              b = if b_op && b_op["op"] == "Const"
                    JSON.generate(Array(b_op["args"]).first)
                  else
                    NameMangler.tmp_for_op(args[1], ns: ns)
                  end
              c = if c_op && c_op["op"] == "Const"
                    JSON.generate(Array(c_op["args"]).first)
                  else
                    NameMangler.tmp_for_op(args[2], ns: ns)
                  end
              lines << "#{id} = (#{a} ? #{b} : #{c})"
            when "LoadDeclaration"
              target = Array(op["args"]).first.to_s
              if inline?(prod_name, op["id"], plan_decl)
                t_plan = @plans.fetch(target)
                t_spec = @decls.fetch(target)
                sub_lines, sub_val = emit_site_scalar_for_decl(
                  prod_name: target, prod_spec: t_spec, plan_decl: t_plan,
                  chain_map: chain_map, scope_axes: scope_axes, ns: target
                )
                lines.concat(sub_lines)
                # Store the mapping from this op's id to the final sub_val for direct substitution
                @inline_substitutions ||= {}
                @inline_substitutions[op["id"]] = sub_val
              else
                t_plan = @plans.fetch(target)
                if Array(t_plan["axes"]).empty? && Array(t_plan["reduce_plans"]).empty?
                  lines << "#{id} = #{NameMangler.eval_method_for(target)}"
                else
                  raise "non-inline dependency #{target} requires loops; planner must inline"
                end
              end
            when "Reduce"
              raise "Reduce in site-scalar body"
            else
              raise "op #{op["op"]} not supported in site-scalar"
            end
          end

          final_id =
            if prod_spec.key?("result_op_id") && !skip_reduce_ops
              NameMangler.tmp_for_op(prod_spec["result_op_id"], ns: ns)
            elsif ops_to_process.any?
              NameMangler.tmp_for_op(ops_to_process.last["id"], ns: ns)
            else
              "nil"
            end

          [lines, final_id]
        end

        private

        def emit_one_op(decl_name, decl_spec, op, reduce_chain: false)
          id = NameMangler.tmp_for_op(op.fetch("id"))
          case op.fetch("op")
          when "LoadInput"
            path = Array(op.fetch("args")).first.join(".")
            const = @chains.fetch(path)
            ["#{id} = __walk__(#{const}, input, cursors)"]
          when "Const"
            lit  = Array(op["args"]).first
            ["#{id} = #{JSON.generate(lit)}"]
          when "LoadDeclaration"
            target = Array(op["args"]).first.to_s
            if inline?(decl_name, op.fetch("id"))
              # TODO: extend site-scalar inlining to work here too
              ["#{id} = #{NameMangler.eval_method_for(target)}"]  # temporary fallback
            else
              ["#{id} = self[:#{target}]"]
            end
          when "Map"
            fn   = op.fetch("attrs").fetch("fn")
            args = Array(op.fetch("args")).map { |ref| NameMangler.tmp_for_op(ref) }.join(", ")
            ["#{id} = __call_kernel__(#{fn.inspect}, #{args})"]
          when "ConstructTuple"
            tuple = Array(op.fetch("args")).map { |ref| NameMangler.tmp_for_op(ref) }.join(", ")
            ["#{id} = [#{tuple}]"]
          when "Select"
            condition = NameMangler.tmp_for_op(Array(op.fetch("args"))[0])
            true_val  = NameMangler.tmp_for_op(Array(op.fetch("args"))[1])
            false_val = NameMangler.tmp_for_op(Array(op.fetch("args"))[2])
            ["#{id} = (#{condition} ? #{true_val} : #{false_val})"]
          when "Reduce"
            # TODO: This should be in fused chains, but temporarily allow for compatibility
            ["#{id} = (raise NotImplementedError, \"Standalone reduce not implemented\")"]
          else
            ["#{id} = (raise NotImplementedError, #{op["op"].inspect})"]
          end
        end


        def inline?(decl_name, op_id, plan_decl = @plans.fetch(decl_name))
          decs = plan_decl.fetch("inlining_decisions", {})
          decs.dig("op_#{op_id}", "decision") == "inline"
        end


      end
    end
  end
end