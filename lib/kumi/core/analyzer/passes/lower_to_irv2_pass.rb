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
              decl = snast.decls.fetch(decl_name)
              
              # Create separate builder for each declaration
              @b = Kumi::Core::IRV2::Builder.new
              @input_cache = {}  # Fresh input cache per declaration
              
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

            irv2_module = IRV2::Module.new(nil, nil, @metadata, declarations)
            state.with(:irv2_module, irv2_module)
          end

          private

          def lower_expr(node, errors)
            ir_val = case node
            when Kumi::Core::NAST::Const
              @b.const(node.value)

            when Kumi::Core::NAST::InputRef
              # Deduplicate LoadInput operations
              @input_cache[node.path] ||= @b.load_input(node.path)

            when Kumi::Core::NAST::Ref
              @b.load_param(node.name)

            when Kumi::Core::NAST::TupleLiteral
              plan    = node.meta[:plan] or raise "Missing plan on TupleLiteral"
              lowered = node.elements.map { |e| lower_expr(e, errors) }
              aligned = apply_aligns(lowered, plan[:needs_expand_flags], plan[:target_axes_tokens])
              @b.construct_tuple(*aligned)

            when Kumi::Core::NAST::Call
              plan = node.meta[:plan] or raise "Missing plan on Call #{node.fn}"
              case plan[:kind]
              when :elementwise
                args    = node.args.map { |a| lower_expr(a, errors) }
                aligned = apply_aligns(args, plan[:needs_expand_flags], plan[:target_axes_tokens])
                @b.map(node.fn.to_s, *aligned)

              when :reduce
                raise "Reducer arity must be 1" unless node.args.size == 1
                v = lower_expr(node.args.first, errors)
                @b.reduce(node.fn.to_s, v, plan[:last_axis_token])

              else
                raise "Unsupported call kind for lowering: #{plan[:kind].inspect}"
              end

            else
              raise "Unhandled SNAST node in lowering: #{node.class}"
            end
            
            # Record metadata for this operation
            raise "Missing IR value from lowering" unless ir_val
            record_operation_metadata(ir_val, node)
            ir_val
          end

          def apply_aligns(ir_args, flags, target_axes)
            return ir_args if flags.nil? || flags.empty?
            raise "flags and ir_args length mismatch" unless flags.length == ir_args.length
            raise "target_axes required for alignment" if target_axes.nil?
            ir_args.each_with_index.map { |v,i| flags[i] ? @b.align_to(v, target_axes) : v }
          end

          def collect_metadata(snast, input_table)
            input_scopes = {}
            input_types = {}
            
            # Collect input metadata
            input_table.each do |path, info|
              input_scopes[path] = info.fetch(:axis)
              input_types[path] = info.fetch(:dtype)
            end

            {
              input_scopes: input_scopes,
              input_types: input_types,
              operation_scopes: {},
              operation_types: {}
            }
          end

          def record_operation_metadata(ir_value, node)
            case ir_value.op
            when :LoadInput
              path = ir_value.args.first
              input_table = get_state(:input_table, required: true)
              info = input_table.fetch(path)
              @metadata[:operation_scopes][ir_value.id] = info.fetch(:axis)
              @metadata[:operation_types][ir_value.id] = info.fetch(:dtype)
            when :Const
              @metadata[:operation_scopes][ir_value.id] = []
              # Infer type from constant value
              value = ir_value.args.first
              @metadata[:operation_types][ir_value.id] = case value
              when Integer then :integer
              when Float then :float
              when String then :string
              when TrueClass, FalseClass then :boolean
              else raise "Unknown constant type: #{value.class}"
              end
            when :AlignTo
              # AlignTo preserves the input type but changes scope
              input_val = ir_value.args.first
              @metadata[:operation_scopes][ir_value.id] = ir_value.attrs.fetch(:axes)
              @metadata[:operation_types][ir_value.id] = @metadata[:operation_types].fetch(input_val.id)
            when :LoadParam
              dep_name = ir_value.args.first
              dep_decl = @current_decls.fetch(dep_name)
              raise "Declaration #{dep_name} missing stamp metadata" unless dep_decl.meta[:stamp]
              stamp = dep_decl.meta.fetch(:stamp)
              @metadata[:operation_scopes][ir_value.id] = stamp.fetch(:axes_tokens)
              @metadata[:operation_types][ir_value.id] = stamp.fetch(:dtype)
            when :Map, :Reduce
              raise "Map/Reduce metadata must come from stamps" unless node&.meta&.[](:stamp)
              stamp = node.meta.fetch(:stamp)
              @metadata[:operation_scopes][ir_value.id] = stamp.fetch(:axes_tokens)
              @metadata[:operation_types][ir_value.id] = stamp.fetch(:dtype)
            when :ConstructTuple
              raise "ConstructTuple metadata must come from stamps" unless node&.meta&.[](:stamp)
              stamp = node.meta.fetch(:stamp)
              @metadata[:operation_scopes][ir_value.id] = stamp.fetch(:axes_tokens)
              @metadata[:operation_types][ir_value.id] = stamp.fetch(:dtype)
            else
              raise "Unhandled IR operation for metadata: #{ir_value.op}"
            end
          end

          def collect_declaration_parameters(operations, input_table, decls)
            parameters = []
            
            # Collect input parameters
            operations.select { |op| op.op == :LoadInput }.each do |op|
              path = op.args.first
              next if parameters.any? { |p| p[:type] == :input && p[:path] == path }
              
              info = input_table.fetch(path)
              parameters << {
                type: :input,
                name: "in_#{path.last}",
                path: path,
                axes: info.fetch(:axis),
                dtype: info.fetch(:dtype)
              }
            end
            
            # Collect dependency parameters  
            operations.select { |op| op.op == :LoadParam }.each do |op|
              dep_name = op.args.first
              next if parameters.any? { |p| p[:type] == :dependency && p[:source] == dep_name }
              
              # Get type info from referenced declaration
              dep_decl = decls.fetch(dep_name)
              raise "Declaration #{dep_name} missing stamp metadata" unless dep_decl.meta[:stamp]
              stamp = dep_decl.meta.fetch(:stamp)
              parameters << {
                type: :dependency,
                name: "dep_#{dep_name}",
                source: dep_name,
                axes: stamp.fetch(:axes_tokens),
                dtype: stamp.fetch(:dtype)
              }
            end
            
            parameters
          end
          
          def optimize_declaration(builder)
            # Simple CSE: find and deduplicate identical operations
            value_map = {}  # operation signature -> first value
            
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
            builder.values.reject! { |val| 
              sig = operation_signature(val)
              value_map[sig] != val
            }
          end
          
          def operation_signature(val)
            # Create signature for CSE matching
            case val.op
            when :LoadParam, :LoadInput
              [val.op, val.args.first]
            when :Const
              [val.op, val.args.first]
            when :AlignTo
              [val.op, val.args.first.id, val.attrs[:axes]]
            when :Map
              [val.op, val.attrs[:op], val.args.map(&:id)]
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