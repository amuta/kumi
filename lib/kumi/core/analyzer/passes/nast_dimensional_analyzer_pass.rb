# frozen_string_literal: true
require_relative "../../functions/loader"

module Kumi
  module Core
    module Analyzer
      module Passes
        # Extracts dimensional and type metadata from NAST tree
        # Uses minimal function specs to resolve Call nodes and propagate types
        #
        # Input: state[:nast_module], state[:input_table] 
        # Output: state[:call_table], state[:declaration_table]
        class NASTDimensionalAnalyzerPass < PassBase
          def run(errors)
            nast_module = get_state(:nast_module, required: true)
            @input_table = get_state(:input_table, required: true)
            
            @function_specs = Functions::Loader.load_minimal_functions
            @metadata_table = {}
            @declaration_table = {}

            debug "Analyzing NAST module with #{nast_module.decls.size} declarations"
            debug "Function specs loaded: #{@function_specs.keys.join(', ')}"

            # Walk each declaration and extract metadata
            nast_module.decls.each do |name, decl|
              analyze_declaration(name, decl, errors)
            end

            debug "Generated metadata_table with #{@metadata_table.size} entries"
            debug "Generated declaration_table with #{@declaration_table.size} entries"

            state.with(:metadata_table, @metadata_table.freeze)
                 .with(:declaration_table, @declaration_table.freeze)
          end

          private


          def analyze_declaration(name, decl, errors)
            debug "Analyzing #{decl.kind} #{name}"
            
            # Analyze the declaration body and extract metadata
            result_metadata = analyze_expression(decl.body, errors)
            
            # Store in both tables
            decl_metadata = {
              kind: decl.kind,
              result_type: result_metadata[:type],
              result_scope: result_metadata[:scope],
              target_name: name
            }.freeze
            
            @metadata_table[node_id(decl)] = decl_metadata
            @declaration_table[name] = decl_metadata

            debug "  #{name}: #{result_metadata[:type]} in scope #{result_metadata[:scope].inspect}"
          end

          def analyze_expression(expr, errors)
            case expr
            when Kumi::Core::NAST::Call
              analyze_call_expression(expr, errors)
            when Kumi::Core::NAST::TupleLiteral
              analyze_tuple_literal(expr, errors)
            when Kumi::Core::NAST::InputRef
              analyze_input_ref(expr, errors)
            when Kumi::Core::NAST::Const
              analyze_const(expr, errors)
            when Kumi::Core::NAST::Ref
              analyze_declaration_ref(expr, errors)
            else
              raise "Unknown NAST node type: #{expr.class}"
            end
          end

          def analyze_call_expression(call, errors)
            function_spec = @function_specs.fetch(call.fn.to_s)

            # Analyze arguments
            arg_metadata = call.args.map { |arg| analyze_expression(arg, errors) }
            arg_types = arg_metadata.map { |meta| meta[:type] }
            arg_scopes = arg_metadata.map { |meta| meta[:scope] }

            # Debug argument count mismatch
            if ENV['DEBUG_NAST_DIMENSIONAL_ANALYZER'] == '1' && function_spec.parameter_names.size != arg_types.size
              puts "[NASTDimensionalAnalyzer]     WARNING: #{call.fn} expects #{function_spec.parameter_names.size} args, got #{arg_types.size}"
            end

            # Compute result type using function spec
            named_types = if function_spec.parameter_names.size == arg_types.size
              Hash[function_spec.parameter_names.zip(arg_types)]
            else
              # Handle variadic functions like core.array, core.and
              param_name = function_spec.parameter_names.first || :elements
              { param_name => arg_types }
            end
            
            result_type = function_spec.dtype_rule.call(named_types)
            result_scope = compute_result_scope(function_spec, arg_scopes)

            # Compute expansion flags for elementwise and constructor operations
            needs_expand_flags = 
              if [:elementwise, :constructor].include?(function_spec.kind)
                arg_scopes.map { |axes| axes != result_scope }
              else
                nil
              end

            # Store call metadata
            @metadata_table[node_id(call)] = {
              function: function_spec.id,
              kind: function_spec.kind,
              parameter_names: function_spec.parameter_names,
              result_type: result_type,
              result_scope: result_scope,
              arg_types: arg_types,
              arg_scopes: arg_scopes,
              needs_expand_flags: needs_expand_flags,
              last_axis_token: (function_spec.kind == :reduce ? (arg_scopes.first || []).last : nil)
            }.freeze

            debug "    Call #{function_spec.id}: (#{arg_types.join(', ')}) -> #{result_type} in #{result_scope.inspect}"

            { type: result_type, scope: result_scope }
          end

          def analyze_tuple_literal(tuple_literal, errors)
            # Analyze all elements
            element_metadata = tuple_literal.elements.map { |elem| analyze_expression(elem, errors) }
            element_types = element_metadata.map { |meta| meta[:type] }
            element_scopes = element_metadata.map { |meta| meta[:scope] }

            # Calculate LUB by prefix for result scope
            result_scope = lub_by_prefix(element_scopes)
            
            # Build tuple type from element types  
            result_type = "tuple<#{element_types.join(', ')}>"

            # Calculate needs_expand_flags (which elements need broadcasting)
            needs_expand_flags = element_scopes.map { |scope| scope != result_scope }

            # Store tuple metadata
            @metadata_table[node_id(tuple_literal)] = {
              function: :tuple_literal,
              kind: :constructor,
              parameter_names: [],
              result_type: result_type,
              result_scope: result_scope,
              arg_types: element_types,
              arg_scopes: element_scopes,
              needs_expand_flags: needs_expand_flags,
              last_axis_token: nil
            }.freeze

            debug "    TupleLiteral: (#{element_types.join(', ')}) -> #{result_type} in #{result_scope.inspect}"

            { type: result_type, scope: result_scope }
          end

          def analyze_input_ref(input_ref, errors)
            path = input_ref.path
            entry = @input_table.fetch(path)
            { type: entry[:dtype], scope: entry[:axis] }
          end

          def analyze_const(const, errors)
            type = case const.value
                   when Integer then :integer
                   when Float then :float
                   when String then :string
                   when true, false then :boolean
                   else raise "Unknown constant type: #{const.value.class}"
                   end

            { type: type, scope: [] } # Constants are scalar
          end

          def analyze_declaration_ref(ref, errors)
            # Since NAST is topologically sorted, referenced declaration should already be analyzed
            referenced_decl_meta = @declaration_table.fetch(ref.name)
            
            # Store metadata for this Ref node too
            @metadata_table[node_id(ref)] = {
              kind: :ref,
              result_type: referenced_decl_meta[:result_type],
              result_scope: referenced_decl_meta[:result_scope],
              referenced_name: ref.name
            }.freeze
            
            { type: referenced_decl_meta[:result_type], scope: referenced_decl_meta[:result_scope] }
          end

          def compute_result_scope(function_spec, arg_scopes)
            case function_spec.kind
            when :elementwise
              # Elementwise operations broadcast to the largest scope
              lub_by_prefix(arg_scopes)
            when :reduce
              # Reduce operations collapse the last dimension
              child = arg_scopes.first || []
              child[0...-1]
            when :constructor
              # Constructors use LUB to handle mixed dimensions
              lub_by_prefix(arg_scopes)
            else
              []
            end
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

          def node_id(node)
            "#{node.class}_#{node.object_id}"
          end
        end
      end
    end
  end
end