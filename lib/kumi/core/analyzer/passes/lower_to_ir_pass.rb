# frozen_string_literal: true

# Minimal, plan-driven LowerToIR.
# All reasoning happens in analyzer passes. This class only:
#   • reads annotations (selected_signature, join_plan) per CallExpression
#   • compiles children
#   • applies explicit lifts from the plan
#   • emits IR ops (Map / Reduce / Lift / LoadInput / Const / Array / Ref / Store / GuardPush/GuardPop / Switch)
#   • materializes vector decls via __vec twin + Lift
# Fail-fast: missing annotations ⇒ DeveloperError.

module Kumi
  module Core
    module Analyzer
      module Passes
        # Brand-new, minimal, plan-driven LowerToIRPass
        class LowerToIRPass < PassBase
          include LowerToIR::Contracts
          include LowerToIR::Access
          include LowerToIR::Emit
          include LowerToIR::Compile

          def run(errors)
            eval_order   = get_state(:evaluation_order, required: true)
            declarations = get_state(:declarations,       required: true)
            access_plans = get_state(:access_plans,       required: true)
            scope_plans  = get_state(:scope_plans,        required: true)
            node_index   = get_state(:node_index,         required: true)
            inputs_meta  = get_state(:input_metadata,     required: true)

            decl_ir = []
            @cache = {}

            eval_order.each do |name|
              decl = declarations[name]
              next unless decl

              @current_decl = name
              compiled_decl = compile_decl(name, decl, access_plans, scope_plans, node_index, errors)
              decl_ir << compiled_decl if compiled_decl
            rescue StandardError => e
              loc = decl.respond_to?(:loc) ? decl.loc : nil
              add_error(errors, loc, "Failed to lower declaration #{name}: #{e.message}")
            ensure
              @cache.clear
            end

            # Preserve topo order
            order = eval_order.each_with_index.to_h
            decl_ir.sort_by! { |d| order.fetch(d.name, Float::INFINITY) }

            ir_module = Kumi::Core::IR::Module.new(inputs: inputs_meta, decls: decl_ir)
            
            # Dump IR operations if requested
            if ENV["DUMP_IR"]
              dump_ir_operations(ir_module, ENV["DUMP_IR"])
            end
            
            state.with(:ir_module, ir_module)
          end

          private

          def dump_ir_operations(ir_module, dump_path)
            File.open(dump_path, 'w') do |f|
              f.puts "=== IR MODULE DUMP ==="
              f.puts "Inputs: #{ir_module.inputs.keys.inspect}"
              f.puts 
              f.puts "Declarations:"
              ir_module.decls.each do |decl|
                f.puts "  #{decl.name}: (#{decl.kind}, shape: #{decl.shape.inspect})"
                f.puts "    operations:"
                decl.ops.each_with_index do |op, i|
                  f.puts "      [#{i}] #{op.tag}: #{op.attrs.inspect}"
                  f.puts "           args: #{op.args.inspect}" if op.args.any?
                end
                f.puts
              end
            end
            puts "IR dumped to #{dump_path}"
          end
        end
      end
    end
  end
end
