# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Semantic NAST Pass - Adds dimensional and type stamps to NAST nodes
        # 
        # Takes NAST + dimensional analyzer metadata and creates a Semantic NAST (SNAST)
        # where every node is annotated with:
        # - meta[:stamp] = {axes_tokens, dtype} 
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
              name: name,
              kind: decl.kind, 
              body: annotated_body,
              loc: decl.loc
            )
            
            # Add declaration-level metadata
            new_decl.meta[:stamp] = {
              axes_tokens: decl_meta[:result_scope],
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
            when Core::NAST::TupleLiteral
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
            new_call = call.class.new(fn: call.fn, args: annotated_args, loc: call.loc)
            
            # Add stamp metadata
            new_call.meta[:stamp] = {
              axes_tokens: call_meta[:result_scope],
              dtype: call_meta[:result_type]
            }.freeze
            new_call.meta[:value_id] = next_value_id
            new_call.meta[:topo_index] = next_topo_index
            
            # Add execution plan
            new_call.meta[:plan] = build_execution_plan(call_meta, annotated_args).freeze
            
            debug "    Call #{call_meta[:function]}: #{call_meta[:arg_scopes]} -> #{call_meta[:result_scope]} (#{call_meta[:result_type]})"
            
            new_call
          end
          
          def annotate_input_ref(input_ref)
            # Get input metadata
            input_meta = @input_table.fetch(input_ref.path)
            
            # Create new input ref
            new_input_ref = input_ref.class.new(path: input_ref.path, loc: input_ref.loc)
            
            # Add stamp metadata
            new_input_ref.meta[:stamp] = {
              axes_tokens: input_meta[:axis],
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
            new_const = const.class.new(value: const.value, loc: const.loc)
            
            # Add stamp metadata (constants are scalar)
            new_const.meta[:stamp] = {
              axes_tokens: [],
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
            new_ref = ref.class.new(name: ref.name, loc: ref.loc)
            
            # Copy stamp from stored metadata
            new_ref.meta[:stamp] = {
              axes_tokens: ref_meta[:result_scope],
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
            
            # Annotate elements first
            annotated_elements = tuple_literal.elements.map { |elem| annotate_expression(elem) }
            
            # Create new tuple literal with annotated elements
            new_tuple = tuple_literal.class.new(elements: annotated_elements, loc: tuple_literal.loc)
            
            # Add stamp metadata (from pre-calculated analysis)
            new_tuple.meta[:stamp] = {
              axes_tokens: tuple_meta[:result_scope],
              dtype: tuple_meta[:result_type]
            }.freeze
            new_tuple.meta[:value_id] = next_value_id
            new_tuple.meta[:topo_index] = next_topo_index
            
            # Add execution plan (from pre-calculated analysis)
            new_tuple.meta[:plan] = {
              kind: :constructor,
              arity: annotated_elements.length,
              target_axes_tokens: tuple_meta[:result_scope],
              needs_expand_flags: tuple_meta[:needs_expand_flags]
            }.freeze
            
            debug "    TupleLiteral: #{tuple_meta[:arg_scopes]} -> #{tuple_meta[:result_scope]} (#{tuple_meta[:result_type]})"
            
            new_tuple
          end
          
          def build_execution_plan(call_meta, annotated_args)
            case call_meta[:kind]
            when :elementwise
              # Elementwise operations broadcast to target scope
              {
                kind: :elementwise,
                target_axes_tokens: call_meta[:result_scope],
                needs_expand_flags: call_meta[:needs_expand_flags]
              }
              
            when :reduce
              # Reduce operations drop the last axis
              {
                kind: :reduce,
                last_axis_token: call_meta[:last_axis_token]
              }
              
            when :constructor
              # Constructor operations create new data structures
              {
                kind: :constructor,
                arity: annotated_args.length,
                target_axes_tokens: call_meta[:result_scope],
                needs_expand_flags: call_meta[:needs_expand_flags]
              }
              
            else
              raise "Unknown function kind: #{call_meta[:kind]}"
            end
          end
          
          
          def next_value_id
            "v#{@value_id_counter += 1}"
          end
          
          def next_topo_index
            @topo_index += 1
          end
          
          def node_id(node)
            "#{node.class}_#{node.object_id}"
          end
        end
      end
    end
  end
end