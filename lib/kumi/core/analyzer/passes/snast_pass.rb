# frozen_string_literal: true
# TODO(LIR) -> its probably possible to get rid of tables 
module Kumi
  module Core
    module Analyzer
      module Passes
        # Semantic NAST Pass - Adds dimensional and type stamps to NAST nodes
        # 
        # Takes NAST + dimensional analyzer metadata and creates a Semantic NAST (SNAST)
        # where every node is annotated with:
        # - meta[:stamp] = {axes, dtype} 
        # - meta[:plan] = execution plan for Call nodes
        # - meta[:value_id] = stable lowering identifier
        # - meta[:topo_index] = topological ordering
        #
        # Input: state[:nast_module], state[:call_table], state[:declaration_table], state[:input_table]
        # Output: state[:snast_module]
        class SNASTPass < PassBase
          def run(errors)
            @nast_module = get_state(:nast_module, required: true)
            @metadata_table = get_state(:metadata_table, required: true)
            @declaration_table = get_state(:declaration_table, required: true)
            @input_table = get_state(:input_table, required: true)
            
            @value_id_counter = 0
            @topo_index = 0
            
            debug "Building SNAST from #{@nast_module.decls.size} declarations"
            
            # Clone NAST and annotate with semantic metadata
            snast_module = annotate_nast_module(@nast_module)
            
            debug "Generated SNAST with #{@value_id_counter} value IDs"
            
            state.with(:snast_module, snast_module.freeze)
          end

          private

          def annotate_nast_module(nast_module)
            # NAST declarations are already topologically sorted
            annotated_decls = {}
            
            nast_module.decls.each do |name, decl|
              annotated_decls[name] = annotate_declaration(name, decl)
            end
            
            # Return new NAST::Module with annotated declarations
            nast_module.class.new(decls: annotated_decls)
          end
          
          def annotate_declaration(name, decl)
            debug "  Annotating #{decl.kind} #{name}"
            
            # Get declaration metadata
            decl_meta = @declaration_table.fetch(name)
            
            # Annotate the declaration body
            annotated_body = annotate_expression(decl.body)
            
            # Create new declaration with same structure
            new_decl = decl.class.new(
              id: decl.id,
              name: name,
              body: annotated_body,
              loc: decl.loc,
              meta: {kind: decl.kind, }
            )
            
            # Add declaration-level metadata
            new_decl.meta[:stamp] = {
              axes: decl_meta[:result_scope],
              dtype: decl_meta[:result_type]
            }.freeze
            new_decl.meta[:value_id] = next_value_id
            new_decl.meta[:topo_index] = next_topo_index
            new_decl.meta[:target_name] = name
            
            new_decl
          end
          
          def annotate_expression(expr)
            case expr
            when Core::NAST::Call
              annotate_call_expression(expr)
            when Core::NAST::Tuple
              annotate_tuple_literal(expr)
            when Core::NAST::InputRef
              annotate_input_ref(expr)
            when Core::NAST::Const
              annotate_const(expr)
            when Core::NAST::Ref
              annotate_declaration_ref(expr)
            else
              raise "Unknown NAST node type: #{expr.class}"
            end
          end
          
          def annotate_call_expression(call)
            # Find call metadata
            call_meta = @metadata_table.fetch(node_id(call))
            
            # Annotate arguments first
            annotated_args = call.args.map { |arg| annotate_expression(arg) }
            
            # Create new call with annotated arguments
            new_call = call.class.new(id: call.id, fn: call.fn, args: annotated_args, loc: call.loc)
            
            # Add stamp metadata
            new_call.meta[:stamp] = {
              axes: call_meta[:result_scope],
              dtype: call_meta[:result_type]
            }.freeze
            new_call.meta[:value_id] = next_value_id
            new_call.meta[:topo_index] = next_topo_index
            
            # Add execution plan
            new_call.meta[:plan] = build_execution_plan(call_meta, annotated_args).freeze
            
            # Apply builtin semantics for core operations
            apply_builtin_semantics!(new_call, call_meta)
            
            debug "    Call #{call_meta[:function]}: #{call_meta[:arg_scopes]} -> #{call_meta[:result_scope]} (#{call_meta[:result_type]})"
            
            new_call
          end
          
          def annotate_input_ref(input_ref)
            input_meta = @input_table.find{|imp| imp.path_fqn == input_ref.path_fqn}
            
            # Create new input ref
            new_input_ref = input_ref.class.new(id: input_ref.id, path: input_ref.path, loc: input_ref.loc)
            
            # Add stamp metadata
            new_input_ref.meta[:stamp] = {
              axes: input_meta[:axes],
              dtype: input_meta[:dtype]
            }.freeze
            new_input_ref.meta[:value_id] = next_value_id
            new_input_ref.meta[:topo_index] = next_topo_index
            
            new_input_ref
          end
          
          def annotate_const(const)
            # Infer type from constant value
            dtype = case const.value
                    when Integer then :integer
                    when Float then :float
                    when String then :string
                    when true, false then :boolean
                    else raise "Unknown constant type: #{const.value.class}"
                    end
            
            # Create new constant
            new_const = const.class.new(id: const.id, value: const.value, loc: const.loc)
            
            # Add stamp metadata (constants are scalar)
            new_const.meta[:stamp] = {
              axes: [],
              dtype: dtype
            }.freeze
            new_const.meta[:value_id] = next_value_id
            new_const.meta[:topo_index] = next_topo_index
            
            new_const
          end
          
          def annotate_declaration_ref(ref)
            # Get ref metadata (stored during dimensional analysis)
            ref_meta = @metadata_table.fetch(node_id(ref))
            
            # Create new ref
            new_ref = ref.class.new(id: ref.id, name: ref.name, loc: ref.loc)
            
            # Copy stamp from stored metadata
            new_ref.meta[:stamp] = {
              axes: ref_meta[:result_scope],
              dtype: ref_meta[:result_type]
            }.freeze
            new_ref.meta[:value_id] = next_value_id
            new_ref.meta[:topo_index] = next_topo_index
            new_ref.meta[:referenced_name] = ref_meta[:referenced_name]
            
            new_ref
          end
          
          def annotate_tuple_literal(tuple_literal)
            # Find tuple metadata
            tuple_meta = @metadata_table.fetch(node_id(tuple_literal))
            
            # Annotate args 
            annotated_args = tuple_literal.args.map { |elem| annotate_expression(elem) }
            
            # Create new tuple literal with annotated args
            new_tuple = tuple_literal.class.new(id: tuple_literal.id, args: annotated_args, loc: tuple_literal.loc)
            
            # Add stamp metadata (from pre-calculated analysis)
            new_tuple.meta[:stamp] = {
              axes: tuple_meta[:result_scope],
              dtype: tuple_meta[:result_type]
            }.freeze
            new_tuple.meta[:value_id] = next_value_id
            new_tuple.meta[:topo_index] = next_topo_index
            
            # Add execution plan (from pre-calculated analysis)
            new_tuple.meta[:plan] = {
              kind: :constructor, # Contruct an Struct/Tuple fn(...) -> "Typed Object" (Hash/Tuple)
              arity: annotated_args.length,
              target_axes: tuple_meta[:result_scope],
              needs_expand_flags: tuple_meta[:needs_expand_flags]
            }.freeze
            
            debug "    Tuple: #{tuple_meta[:arg_scopes]} -> #{tuple_meta[:result_scope]} (#{tuple_meta[:result_type]})"
            
            new_tuple
          end
          
          def build_execution_plan(call_meta, annotated_args)
            case call_meta[:kind]
            when :elementwise
              # Elementwise operations broadcast to target scope
              {
                kind: :elementwise,
                target_axes: call_meta[:result_scope],
                needs_expand_flags: call_meta[:needs_expand_flags]
              }
              
            when :reduce
              # Reduce operations drop the last axis
              {
                kind: :reduce,
                last_axis_token: call_meta[:last_axis_token]
              }
              
              {
                kind: :constructor,
                arity: annotated_args.length,
                target_axes: call_meta[:result_scope],
                needs_expand_flags: call_meta[:needs_expand_flags]
              }
              
            else
              raise "Unknown function kind: #{call_meta[:kind]}"
            end
          end
          
          def apply_builtin_semantics!(call, call_meta)
            case call.fn
            when BUILTIN_SELECT
              canonicalize_select!(call)
            end
          end
          
          def canonicalize_select!(call)
            cond, then_v, else_v = call.args
            c_axes = Array(cond.meta[:stamp][:axes])
            t_axes = Array(then_v.meta[:stamp][:axes])
            e_axes = Array(else_v.meta[:stamp][:axes])
          
            # LUB by prefix for data branches
            candidate = lub_by_prefix([t_axes, e_axes])
          
            # If both branches are scalar, lift to the mask’s axes
            target_axes = candidate.empty? ? c_axes : candidate
          
            # Mask must be a prefix of target_axes
            unless c_axes.each_with_index.all? { |tok, i| target_axes[i] == tok }
              raise Kumi::Core::Errors::SemanticError,
                    "select mask axes #{c_axes.inspect} must be a prefix of result axes #{target_axes.inspect}"
            end
          
            # DType follows data branches (they’re identical in *_if macros)
            result_dtype = then_v.meta[:stamp][:dtype]
          
            call.meta[:stamp] = {
              axes: target_axes,
              dtype: result_dtype
            }.freeze
          
            call.meta[:plan] = {
              kind: :elementwise,
              target_axes: target_axes,
              needs_expand_flags: [
                c_axes != target_axes,  # broadcast mask across trailing dims
                t_axes != target_axes,  # broadcast then-branch (e.g., scalar 1)
                e_axes != target_axes   # broadcast else-branch (e.g., scalar 0)
              ]
            }.freeze
          end

          def next_value_id
            "v#{@value_id_counter += 1}"
          end
          
          def next_topo_index
            @topo_index += 1
          end
          
          def node_id(node)
            "#{node.class}_#{node.id}"
          end

          def lub_by_prefix(list_of_axes_arrays)
            return [] if list_of_axes_arrays.empty?
            candidate = list_of_axes_arrays.max_by(&:length)
            list_of_axes_arrays.each do |axes|
              unless axes.each_with_index.all? { |tok, i| candidate[i] == tok }
                raise Kumi::Core::Errors::SemanticError, "prefix mismatch: #{axes.inspect} vs #{candidate.inspect}"
              end
            end
            candidate
          end
        end
      end
    end
  end
end