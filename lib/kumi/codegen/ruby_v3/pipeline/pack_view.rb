# frozen_string_literal: true

# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::PackView

module Kumi
  module Codegen
    module RubyV3
      module Pipeline
        class PackView
          def initialize(pack)
            @pack   = pack
            @decls  = pack.fetch("declarations")
            @inputs = pack.fetch("inputs")
            @by_name = @decls.to_h { |d| [d.fetch("name"), d] }

            # Index inputs by fully qualified path ("a.b.c")
            @input_by_fqn = {}
            @inputs.each do |inp|
              fqn = (inp["path_fqn"] || inp["name"]).to_s
              @input_by_fqn[fqn] = inp
            end
          end

          def declarations_in_order
            @decls.map { _1.fetch("name") }
          end

          def decl_spec(name)
            d = @by_name.fetch(name)
            { operations: d.fetch("operations"), result_op_id: d.fetch("result_op_id") }
          end

          def decl_plan(name)
            d = @by_name.fetch(name)
            {
              axes: d.fetch("axes"),
              axis_carriers: d.fetch("axis_carriers", []),
              reduce_plans: d.fetch("reduce_plans", []),
              site_schedule: d.fetch("site_schedule"),
              inlining_decisions: d.fetch("inlining_decisions", {})
            }
          end

          def axes_of_decl(name) = decl_plan(name)[:axes]
          def producer_axes(name) = axes_of_decl(name)

          # ---- New: input spec lookup (path array → input record from pack.inputs) ----
          def input_spec_for_path(path_array)
            key = Array(path_array).map(&:to_s).join(".")
            @input_by_fqn.fetch(key) { raise KeyError, "Input spec not found for path #{path_array.inspect} (#{key})" }
          end

          # Authoritative axis loops for a declaration (used by StreamLowerer to open loops)
          def axis_loops_for_decl(name, producer_cache: {})
            ctx = decl_plan(name)
            ops = decl_spec(name)[:operations]

            # 1) Direct LoadInput
            if (li = ops.find { |o| o["op"] == "LoadInput" })
              return Array(input_spec_for_path(li["args"].first)["axis_loops"])
            end

            # 2) Via axis carriers (choose last for deepest required loops)
            if ctx[:axis_carriers].any?
              path = ctx[:axis_carriers].last.fetch("via_path")
              return Array(input_spec_for_path(path)["axis_loops"])
            end

            # 3) Inline producer (use producer's LoadInput path)
            inline = ops.find do |op|
              op["op"] == "LoadDeclaration" &&
                ctx[:inlining_decisions].dig("op_#{op['id']}", "decision") == "inline"
            end
            if inline
              producer = inline["args"].first.to_s
              if (pc = producer_cache[producer])
                pctx = pc[:ctx]
                pli = pctx[:ops].find { |o| o["op"] == "LoadInput" }
                if pli
                  return Array(input_spec_for_path(pli["args"].first)["axis_loops"])
                end
              end
            end

            # 4) Scalar / rank-0 fallback
            []
          end
        end
      end
    end
  end
end