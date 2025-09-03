# frozen_string_literal: true

require_relative "name_mangler"
require_relative "loop_builder"
require_relative "ops_emitter"

module Kumi
  module Codegen
    module RubyV2
      module DeclarationEmitter
        module_function

        def render_one(decl_name:, decl_spec:, chain_map:, ops_by_decl:)
          # With merged format, planning data is in decl_spec itself
          axes         = decl_spec.fetch("axes")
          reduce_plans = decl_spec.fetch("reduce_plans", [])
          hoisted_ids  = decl_spec.dig("site_schedule","hoisted_scalars")&.map { |h| h.fetch("id") } || []

          ops = OpsEmitter.new(
            plan_decl_by_name: ops_by_decl,  # Now contains merged data
            chain_const_by_input_name: chain_map,
            ops_by_decl: ops_by_decl
          )

          mname = NameMangler.eval_method_for(decl_name)

          # Check if this declaration has reduces to fuse
          if reduce_plans.any?
            render_reduce_chain(decl_name, mname, decl_spec, ops, hoisted_ids, reduce_plans, axes)
          else
            render_site_loops(decl_name, mname, decl_spec, ops, axes, hoisted_ids)
          end
        end

        def render_reduce_chain(decl_name, mname, decl_spec, ops, hoisted_ids, reduce_plans, axes = [])
          if axes.empty?
            # Pure reduce case - no site axes
            render_pure_reduce_chain(decl_name, mname, decl_spec, ops, hoisted_ids, reduce_plans)
          else
            # Site + reduce case - need to compose site loops with reduce chain
            render_site_plus_reduce(decl_name, mname, decl_spec, ops, hoisted_ids, reduce_plans, axes)
          end
        end

        def render_pure_reduce_chain(decl_name, mname, decl_spec, ops, hoisted_ids, reduce_plans)
          rheader, rfooter, cursors_line, axis_vars = LoopBuilder.build_reduce_chain(reduce_plans)
          hoisted_lines = ops.emit_ops_subset(decl_name, decl_spec, only_ids: hoisted_ids, reduce_chain: false)
          
          # Use site-scalar emission for the inner body
          scope_axes = axis_vars.map { |v| v.sub(/^a_/, '') }
          site_lines, site_val = ops.emit_site_scalar_for_decl(
            prod_name: decl_name,
            prod_spec: decl_spec,
            chain_map: ops.instance_variable_get(:@chains),
            scope_axes: scope_axes,
            ns: "inline"
          )

          acc_var = "acc"
          inner = +""
          inner << ("  " * axis_vars.length) << "#{cursors_line}\n"
          inner << indent(site_lines.join("\n"), axis_vars.length)
          inner << "\n" << ("  " * axis_vars.length) << "#{acc_var} += #{site_val}\n"

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

        def render_site_plus_reduce(decl_name, mname, decl_spec, ops, hoisted_ids, reduce_plans, axes)
          # Build site loops first
          site_header, _, site_cursors_line, out_var, row_vars = LoopBuilder.build_nested_loops(axes)
          hoisted_lines = ops.emit_ops_subset(decl_name, decl_spec, only_ids: hoisted_ids, reduce_chain: false)
          
          # Build reduce chain to nest inside site loops with scope_axes support
          reduce_header, reduce_footer, combined_cursors, reduce_axis_vars = LoopBuilder.build_reduce_chain(reduce_plans, scope_axes: axes)
          
          # Build the inner reduce body using site-scalar emission
          scope_axes = axes + reduce_axis_vars.map { |v| v.sub(/^a_/, '') }
          site_lines, site_val = ops.emit_site_scalar_for_decl(
            prod_name: decl_name,
            prod_spec: decl_spec,
            chain_map: ops.instance_variable_get(:@chains),
            scope_axes: scope_axes,
            ns: "inline"
          )

          acc_var = "acc"
          
          # Build the nested structure: site loops -> reduce loops -> body
          inner_depth = axes.length + reduce_axis_vars.length
          inner = +""
          inner << ("  " * inner_depth) << "#{combined_cursors}\n"
          inner << indent(site_lines.join("\n"), inner_depth)
          inner << "\n" << ("  " * inner_depth) << "#{acc_var} += #{site_val}\n"

          # Build the complete method with site loops containing reduce loops
          site_footer = build_site_footer(axes, row_vars, acc_var)
          
          # Build the method - accumulator should be reset at the right level
          # Use the explicit result_depth from planning instead of inferring from axes.length
          result_depth = reduce_plans.first["result_depth"]
          site_with_acc = insert_acc_reset(site_header, result_depth, acc_var)
          
          <<~RUBY
            def #{mname}
              input = @input
        #{indent(hoisted_lines.join("\n"), 2)}
              #{site_with_acc}#{indent("#{reduce_header}#{inner}#{reduce_footer}", axes.length + 1)}
#{site_footer}
              #{out_var}
            end
          RUBY
        end


        def insert_acc_reset(site_header, axes_length, acc_var)
          # Insert the accumulator reset at the innermost site loop level
          # The site header ends with the innermost loop opening, so we add the acc reset after that
          site_header + ("  " * axes_length) + "#{acc_var} = 0\n"
        end

        def build_site_footer(axes, row_vars, acc_var)
          footer = +""
          (axes.length - 1).downto(0) do |i|
            if i == axes.length - 1
              # Append the accumulated result at the innermost site loop level (where acc is scoped)
              target = row_vars[i - 1] if i > 0
              target ||= "out"  
              footer << ("  " * (i + 1)) << "#{target} << #{acc_var}\n"
            elsif i < axes.length - 1 && i > 0
              footer << ("  " * (i + 1)) << "#{row_vars[i - 1]} << #{row_vars[i]}\n"
            end
            
            # Before closing this loop level, append row to out if this is where the row is declared
            if i == 0 && row_vars[0]  # At the outermost level (where row_0 is declared)
              footer << "  out << #{row_vars[0]}\n"
            end
            
            # Close the current loop
            footer << ("  " * i) << "end\n"
          end
          
          footer
        end

        def render_site_loops(decl_name, mname, decl_spec, ops, axes, hoisted_ids)
          header, _, cursors_line, out_var, row_vars = LoopBuilder.build_nested_loops(axes)
          hoisted_lines = ops.emit_ops_subset(decl_name, decl_spec, only_ids: hoisted_ids, reduce_chain: false)
          body_lines, result_var = ops.emit_body_for_decl(decl_name, decl_spec, skip_ids: hoisted_ids, reduce_chain: false)

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
            inner << ("  " * axes.length) << "#{cursors_line}\n"
            inner << indent(body_lines.join("\n"), axes.length + 1) << "\n"
            
            # Add result appending and build footer
            target = row_vars.last || out_var
            inner << ("  " * axes.length) << "#{target} << #{result_var}\n"
            
            footer = build_footer(axes, row_vars)

            <<~RUBY
              def #{mname}
                input = @input
          #{indent(hoisted_lines.join("\n"), 2)}
                #{header}#{indent(inner, 1)}
#{indent(footer, 1)}
                #{out_var}
              end
            RUBY
          end
        end

        def build_footer(axes, row_vars)
          footer = +""
          (axes.length - 1).downto(0) do |i|
            if i.zero?
              footer << "  out << #{row_vars[0]}\n" if row_vars[0]
            elsif i < axes.length - 1
              footer << ("  " * (i + 1)) << "#{row_vars[i - 1]} << #{row_vars[i]}\n"
            end
            footer << ("  " * i) << "end\n"
          end
          footer
        end


        def indent(str, n)
          pref = "  " * n
          str.split("\n").map { |l| pref + l }.join("\n")
        end
      end
    end
  end
end