# frozen_string_literal: true

require_relative "../../irv2/builder"

module Kumi
  module Core
    module Analyzer
      module Passes
        class LowerToIRV2Pass < PassBase
          # In:  state[:snast_module], state[:evaluation_order], state[:input_table]
          # Out: state[:irv2_module]
          def run(errors)
            snast = get_state(:snast_module, required: true)
            order = get_state(:evaluation_order, required: true)
            @input_table = get_state(:input_table, required: true)

            builder = Kumi::Core::IRV2::Builder.new
            declarations = {}

            order.each do |decl_name|
              declarations[decl_name] = lower_one_declaration(decl_name, snast, @input_table, builder, errors)
            end

            irv2_module = IRV2::Module.new(declarations, {})
            state.with(:irv2_module, irv2_module)
          end

          private

          def lower_one_declaration(decl_name, snast, input_table, builder, errors)
            decl = snast.decls.fetch(decl_name)
            
            # Temporarily set instance variables for the context of this declaration.
            @current_decl_name = decl_name
            @b = builder # Use the shared builder
            @input_cache = {}
            @current_input_table = @input_table
            @current_decls = snast.decls

            start_op_count = builder.values.length
            ir_val = lower_expr(decl.body, errors)
            
            # Note: The optimizer and parameter collection now need to operate on a slice of the builder's operations.
            new_ops = builder.values.slice(start_op_count..-1)
            parameters = collect_declaration_parameters(new_ops, snast.decls)

            # The declaration now just stores references to the globally unique operations.
            IRV2::Declaration.new(decl_name, new_ops, ir_val, parameters)
          ensure
            # Clean up instance variables
            @current_decl_name = @b = @input_cache = @current_input_table = @current_decls = nil
          end

          def fqid(val)
            "#{@current_decl_name}/#{val.id}"
          end

          def ser_stamp(snast_stamp)
            {
              "dtype" => (snast_stamp["dtype"] || snast_stamp[:dtype]).to_s,
              "axes"  => Array(snast_stamp["axes"] || snast_stamp[:axes]).map(&:to_s)
            }
          end

          def lower_expr(node, errors)
            ir_val =
              case node
              when Kumi::Core::NAST::Const
                stamp = ser_stamp(node.meta[:stamp])
                @b.const(node.value, stamp: stamp)

              when Kumi::Core::NAST::InputRef
                plan = @input_table.find{|i| i.path_fqn == node.path_fqn}
                unless @input_cache[node.path_fqn]
                  axes  = plan.axes
                  dtype = plan.dtype
                  stamp = { "dtype" => dtype.to_s, "axes" => axes.map(&:to_s) }
                  @input_cache[node.path_fqn] = @b.load_input(node.path_fqn, stamp: stamp)
                end
                @input_cache[node.path_fqn]

              when Kumi::Core::NAST::Ref
                dep_name = node.name
                stamp = ser_stamp(@current_decls[dep_name].meta[:stamp])
                @b.load_declaration(dep_name.to_s, stamp: stamp)

              when Kumi::Core::NAST::Tuple
                plan = node.meta[:plan] or (errors << "Missing plan on Tuple"; return @b.const(nil))

                stamp = ser_stamp(node.meta[:stamp])
                lowered = node.elements.map { |e| lower_expr(e, errors) }
                elem_stamps = node.elements.map { |elem| ser_stamp(elem.meta[:stamp]) }

                @b.construct_tuple(*lowered, stamp: stamp)

              when Kumi::Core::NAST::Call
                plan = node.meta[:plan] or (errors << "Missing plan on Call #{node.fn}"; return @b.const(nil))

                case plan[:kind]
                when :elementwise
                  args  = node.args.map { |a| lower_expr(a, errors) }
                  stamp = ser_stamp(node.meta[:stamp])
                  if node.fn == BUILTIN_SELECT
                    @b.select(*args, stamp: stamp)
                  else
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

            ir_val or (errors << "Missing IR value from lowering"; @b.const(nil))
          end

          def collect_declaration_parameters(operations, _decls)
            parameters = []

            operations.select { |op| op.op == :LoadInput }.each do |op|
              path = op.args.first
              next if parameters.any? { |p| p[:type] == :input && p[:source] == path }
              parameters << { type: :input, source: path }
            end

            operations.select { |op| op.op == :LoadDeclaration }.each do |op|
              dep_name = op.args.first
              next if parameters.any? { |p| p[:type] == :dependency && p[:source] == dep_name }
              parameters << { type: :dependency, source: dep_name }
            end

            parameters
          end

          def optimize_declaration(builder)
            value_map = {}

            builder.values.each do |val|
              signature = operation_signature(val)
              if value_map[signature]
                original = value_map[signature]
                replace_references(builder.values, val, original)
              else
                value_map[signature] = val
              end
            end

            builder.values.reject! do |val|
              signature = operation_signature(val)
              value_map[signature] != val
            end
          end

          def operation_signature(val)
            case val.op
            when :LoadDeclaration, :LoadInput, :Const
              [val.op, val.args.first]
            when :AlignTo
              [val.op, val.args.first.id, Array(val.attrs[:target_axes]).map(&:to_s)]
            when :Map
              [val.op, val.attrs[:fn], val.args.map(&:id)]
            when :Reduce
              [val.op, val.args.first.id, val.attrs[:axis].to_s, val.attrs[:fn]]
            else
              [val.op, val.args.map(&:id), val.attrs]
            end
          end

          def replace_references(operations, old_val, new_val)
            operations.each do |op|
              op.args.map! { |arg| arg == old_val ? new_val : arg }
            end
          end
        end
      end
    end
  end
end
