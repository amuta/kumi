# frozen_string_literal: true

require_relative "../../irv2/builder"

module Kumi
  module Core
    module Analyzer
      module Passes
        class LowerToIRV2Pass < PassBase
          # In:  state[:snast_module], state[:evaluation_order]
          # Out: state[:irv2_module]
          def run(errors)
            snast = get_state(:snast_module, required: true)
            order = get_state(:evaluation_order, required: true)
            input_table = get_state(:input_table, required: true)

            @metadata = collect_metadata(snast, input_table)
            declarations = {}

            order.each do |decl_name|
              decl = snast.decls[decl_name]

              @current_decl_name = decl_name # Track current declaration

              # Create separate builder for each declaration
              @b = Kumi::Core::IRV2::Builder.new
              @input_cache = {} # Fresh input cache per declaration

              # Store references to input_table and decls for metadata
              @current_input_table = input_table
              @current_decls = snast.decls

              # Lower the declaration body
              ir_val = lower_expr(decl.body, errors)

              # Apply within-declaration CSE
              optimize_declaration(@b)

              # Collect parameters (inputs and dependencies) used in this declaration
              parameters = collect_declaration_parameters(@b.values, input_table, snast.decls)

              # Create the declaration
              declarations[decl_name] = IRV2::Declaration.new(
                decl_name,
                @b.values,
                ir_val,
                parameters
              )
            end

            irv2_module = IRV2::Module.new(declarations, @metadata)
            state.with(:irv2_module, irv2_module)
          end

          private

          # Helper for qualified metadata keys
          def fqid(val)
            "#{@current_decl_name}/#{val.id}"
          end

          # Serialize SNAST stamp to IR stamp format
          def ser_stamp(snast_stamp)
            {
              "dtype" => snast_stamp[:dtype].to_s,
              "axes" => Array(snast_stamp[:axes_tokens]).map(&:to_s)
            }
          end

          def lower_expr(node, errors)
            ir_val = case node
                     when Kumi::Core::NAST::Const
                       stamp = ser_stamp(node.meta[:stamp])
                       @b.const(node.value, stamp: stamp)

                     when Kumi::Core::NAST::InputRef
                       # Deduplicate LoadInput operations
                       path = node.path
                       unless @input_cache[path]
                         info = @current_input_table[path]
                         stamp = { "dtype" => info[:dtype].to_s, "axes" => info[:axis].map(&:to_s) }
                         @input_cache[path] = @b.load_input(path, stamp: stamp)
                       end
                       @input_cache[path]

                     when Kumi::Core::NAST::Ref
                       dep_name = node.name
                       stamp = ser_stamp(@current_decls[dep_name].meta[:stamp])
                       @b.load_declaration(dep_name.to_s, stamp: stamp)

                     when Kumi::Core::NAST::TupleLiteral
                       plan = node.meta[:plan]
                       unless plan
                         errors << "Missing plan on TupleLiteral"
                         return @b.const(nil)
                       end
                       lowered = node.elements.map { |e| lower_expr(e, errors) }
                       #  aligned = apply_aligns(lowered, plan[:needs_expand_flags], plan[:target_axes_tokens])
                       elem_stamps = node.elements.map { |elem| ser_stamp(elem.meta[:stamp]) }
                       @b.construct_tuple(*lowered, elem_stamps: elem_stamps)

                     when Kumi::Core::NAST::Call
                       plan = node.meta[:plan]
                       unless plan
                         errors << "Missing plan on Call #{node.fn}"
                         return @b.const(nil)
                       end
                       case plan[:kind]
                       when :elementwise
                         # Handle builtin select operation
                         if node.fn == BUILTIN_SELECT
                           args = node.args.map { |a| lower_expr(a, errors) }
                           #  aligned = apply_aligns(args, plan[:needs_expand_flags], plan[:target_axes_tokens])
                           stamp = ser_stamp(node.meta[:stamp])
                           @b.select(*args, stamp: stamp)
                         else
                           args = node.args.map { |a| lower_expr(a, errors) }
                           #  aligned = apply_aligns(args, plan[:needs_expand_flags], plan[:target_axes_tokens])
                           stamp = ser_stamp(node.meta[:stamp])
                           @b.map(node.fn.to_s, *args, stamp: stamp)
                         end

                       when :reduce
                         unless node.args.size == 1
                           errors << "Reducer arity must be 1, got #{node.args.size}"
                           return @b.const(nil)
                         end
                         v = lower_expr(node.args.first, errors)
                         stamp = ser_stamp(node.meta[:stamp])
                         @b.reduce(node.fn.to_s, v, plan[:last_axis_token], stamp: stamp)

                       else
                         errors << "Unsupported call kind for lowering: #{plan[:kind].inspect}"
                         return @b.const(nil)
                       end

                     else
                       errors << "Unhandled SNAST node in lowering: #{node.class}"
                       return @b.const(nil)
                     end

            # Embed type information directly on the operation
            unless ir_val
              errors << "Missing IR value from lowering"
              return @b.const(nil)
            end
            ir_val
          end

          def apply_aligns(ir_args, flags, target_axes)
            return ir_args if flags.nil? || flags.empty?
            return ir_args unless flags.length == ir_args.length
            return ir_args if target_axes.nil?

            axes = Array(target_axes).map(&:to_s) # Normalize once
            ir_args.each_with_index.map do |v, i|
              if flags[i]
                # AlignTo preserves dtype but changes axes
                input_stamp = v.stamp
                if input_stamp
                  align_stamp = {
                    "dtype" => input_stamp["dtype"],
                    "axes" => axes
                  }
                  @b.align_to(v, axes, stamp: align_stamp)
                else
                  @b.align_to(v, axes)
                end
              else
                v
              end
            end
          end

          def collect_metadata(snast, input_table)
            # Minimal metadata - type info now embedded in operation stamps
            {}
          end

          def collect_declaration_parameters(operations, input_table, decls)
            parameters = []

            # Collect input parameters (simplified - type info now in embedded stamps)
            operations.select { |op| op.op == :LoadInput }.each do |op|
              path = op.args.first
              next if parameters.any? { |p| p[:type] == :input && p[:source] == path }

              parameters << {
                type: :input,
                source: path
              }
            end

            # Collect dependency parameters (simplified - type info now in embedded stamps)
            operations.select { |op| op.op == :LoadDeclaration }.each do |op|
              dep_name = op.args.first
              next if parameters.any? { |p| p[:type] == :dependency && p[:source] == dep_name }

              parameters << {
                type: :dependency,
                source: dep_name
              }
            end

            parameters
          end

          def optimize_declaration(builder)
            # Simple CSE: find and deduplicate identical operations
            value_map = {} # operation signature -> first value

            builder.values.each do |val|
              signature = operation_signature(val)

              if value_map[signature]
                # Found duplicate - replace references
                original = value_map[signature]
                replace_references(builder.values, val, original)
              else
                value_map[signature] = val
              end
            end

            # Remove duplicated values (now unreferenced)
            builder.values.reject! do |val|
              sig = operation_signature(val)
              value_map[sig] != val
            end
          end

          def operation_signature(val)
            # Create signature for CSE matching
            case val.op
            when :LoadDeclaration, :LoadInput, :Const
              [val.op, val.args.first]
            when :AlignTo
              [val.op, val.args.first.id, Array(val.attrs[:target_axes]).map(&:to_s)]
            when :Map
              [val.op, val.attrs[:fn], val.args.map(&:id)]
            when :Reduce
              last = val.attrs[:axis]
              [val.op, val.args.first.id, last.to_s, val.attrs[:fn]]
            else
              [val.op, val.args.map(&:id), val.attrs]
            end
          end

          def replace_references(operations, old_val, new_val)
            operations.each do |op|
              op.args.map! { |arg| arg == old_val ? new_val : arg }
            end
          end

          private
        end
      end
    end
  end
end
