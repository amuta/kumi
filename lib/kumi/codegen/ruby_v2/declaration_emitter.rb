# frozen_string_literal: true

require_relative "name_mangler"
require_relative "loop_builder"
require_relative "ops_emitter"

module Kumi
  module Codegen
    module RubyV2
      module DeclarationEmitter
        module_function

        def render_one(decl_name:, decl_spec:, plan_decl:, chain_map:)
          axes         = Array(plan_decl.fetch("axes"))
          reduce_plans = Array(plan_decl.fetch("reduce_plans", []))
          hoisted_ids  = Array(plan_decl.dig("site_schedule","hoisted_scalars")).map { |h| h.fetch("id") }

          ops = OpsEmitter.new(
            plan_decl_by_name: { decl_name => plan_decl },
            chain_const_by_input_name: chain_map
          )

          mname = NameMangler.eval_method_for(decl_name)

          # Check if this is a scalar declaration with nested reduces
          if axes.empty? && reduce_plans.any?
            render_reduce_chain(mname, decl_spec, plan_decl, ops, hoisted_ids, reduce_plans)
          else
            render_site_loops(mname, decl_spec, plan_decl, ops, axes, hoisted_ids)
          end
        end

        def render_reduce_chain(mname, decl_spec, plan_decl, ops, hoisted_ids, reduce_plans)
          rheader, rfooter, cursors_line, axis_vars = LoopBuilder.build_reduce_chain(reduce_plans)
          hoisted_lines = ops.emit_ops_subset(plan_decl.fetch("name"), decl_spec, only_ids: hoisted_ids, reduce_chain: false)
          
          # Emit non-Reduce operations for the innermost body - skip actual Reduce operation IDs
          all_ops = decl_spec.fetch("operations")
          reduce_ids = all_ops.select { |op| op.fetch("op") == "Reduce" }.map { |op| op.fetch("id") }
          body_lines, _result_var = ops.emit_body_for_decl(plan_decl.fetch("name"), decl_spec, skip_ids: hoisted_ids + reduce_ids, reduce_chain: true)

          # For reduce chains, find the actual result from non-Reduce operations
          non_reduce_ops = all_ops.reject { |op| reduce_ids.include?(op.fetch("id")) || hoisted_ids.include?(op.fetch("id")) }
          final_op_id = non_reduce_ops.last&.fetch("id")
          result_var = final_op_id ? NameMangler.tmp_for_op(final_op_id) : "result"

          acc_var = "acc"
          inner = +""
          inner << ("  " * axis_vars.length) << "#{cursors_line}\n"
          inner << indent(body_lines.join("\n"), axis_vars.length)
          inner << "\n" << ("  " * axis_vars.length) << "#{acc_var} += #{result_var}\n"

          <<~RUBY
            def #{mname}
              input = @input
        #{indent(hoisted_lines.join("\n"), 2)}
              #{acc_var} = 0
              #{rheader}#{inner}#{rfooter}
              #{acc_var}
            end
          RUBY
        end

        def render_site_loops(mname, decl_spec, plan_decl, ops, axes, hoisted_ids)
          header, footer, cursors_line, out_var, row_vars = LoopBuilder.build_nested_loops(axes)
          hoisted_lines = ops.emit_ops_subset(plan_decl.fetch("name"), decl_spec, only_ids: hoisted_ids, reduce_chain: false)
          body_lines, result_var = ops.emit_body_for_decl(plan_decl.fetch("name"), decl_spec, skip_ids: hoisted_ids, reduce_chain: false)

          if header.empty?
            <<~RUBY
              def #{mname}
                input = @input
                cursors = {}
          #{indent(hoisted_lines.join("\n"), 2)}
          #{indent(body_lines.join("\n"), 2)}
                #{result_var}
              end
            RUBY
          else
            inner = +""
            inner << "  " * axes.length << "#{cursors_line}\n"
            inner << indent(body_lines.join("\n"), axes.length + 1)
            target = row_vars.last || out_var
            inner << "\n" << ("  " * axes.length) << "#{target} << #{result_var}\n"

            <<~RUBY
              def #{mname}
                input = @input
          #{indent(hoisted_lines.join("\n"), 2)}
                #{header}#{indent(inner, 1)}#{footer}
                #{out_var}
              end
            RUBY
          end
        end

        def indent(str, n)
          pref = "  " * n
          str.split("\n").map { |l| pref + l }.join("\n")
        end
      end
    end
  end
end