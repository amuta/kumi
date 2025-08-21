# frozen_string_literal: true

require "json"

module Kumi
  module Support
    module IRRender
      module_function

      # Stable JSON for goldens (simple canonical serialization)
      def to_json(ir_module, pretty: true)
        raise "nil IR" unless ir_module

        data = {
          inputs: ir_module.inputs,
          decls: ir_module.decls.map do |decl|
            {
              name: decl.name,
              kind: decl.kind,
              shape: decl.shape,
              ops: decl.ops.map do |op|
                {
                  tag: op.tag,
                  attrs: op.attrs,
                  args: op.args
                }
              end
            }
          end
        }

        if pretty
          JSON.pretty_generate(data)
        else
          JSON.generate(data)
        end
      end

      # Human pretty text (using IRDump)
      def to_text(ir_module, analysis_state: nil)
        raise "nil IR" unless ir_module

        if defined?(Kumi::Support::IRDump)
          # Convert AnalysisState to hash if needed
          state_hash = analysis_state.to_h
        else
          # Fallback: simple text representation
          lines = []
          lines << "IR Module (#{ir_module.decls.size} declarations):"
          ir_module.decls.each_with_index do |decl, i|
            lines << "  [#{i}] #{decl.kind.upcase} #{decl.name} (#{decl.ops.size} ops)"
            decl.ops.each_with_index do |op, j|
              lines << "    #{j}: #{op.tag.upcase} #{op.attrs.inspect} #{op.args.inspect}"
            end
          end
          lines.join("\n")
        end
      end
    end
  end
end
