# frozen_string_literal: true
require_relative "../../functions/loader"

module Kumi
  module Core
    module Analyzer
      module Passes
        # Extracts dimensional and type metadata from NAST tree
        # Uses minimal function specs to resolve Call nodes and propagate types
        #
        # Input:  state[:nast_module], state[:input_table] (chain-free; must include :axes and :dtype per path)
        # Output: state[:metadata_table], state[:declaration_table]
        class NASTDimensionalAnalyzerPass < PassBase
          def run(errors)
            nast_module  = get_state(:nast_module, required: true)
            @input_table = get_state(:input_table, required: true)

            @function_specs    = Functions::Loader.load_minimal_functions
            @metadata_table    = {}
            @declaration_table = {}

            debug "Analyzing NAST module with #{nast_module.decls.size} declarations"
            debug "Function specs loaded: #{@function_specs.keys.join(', ')}"

            nast_module.decls.each { |name, decl| analyze_declaration(name, decl, errors) }

            debug "Generated metadata_table with #{@metadata_table.size} entries"
            debug "Generated declaration_table with #{@declaration_table.size} entries"

            state.with(:metadata_table, @metadata_table.freeze)
                 .with(:declaration_table, @declaration_table.freeze)
          end

          private

          def analyze_declaration(name, decl, errors)
            debug "Analyzing #{name}"
            result_metadata = analyze_expression(decl.body, errors)

            decl_metadata = {
              kind:         decl.kind,
              result_type:  result_metadata[:type],
              result_scope: result_metadata[:scope],
              target_name:  name
            }.freeze

            @metadata_table[node_id(decl)] = decl_metadata
            @declaration_table[name] = decl_metadata

            debug "  #{name}: #{result_metadata[:type]} in scope #{result_metadata[:scope].inspect}"
          end

          def analyze_expression(expr, errors)
            case expr
            when Kumi::Core::NAST::Call         then analyze_call_expression(expr, errors)
            when Kumi::Core::NAST::Tuple        then analyze_tuple_literal(expr, errors)
            when Kumi::Core::NAST::InputRef     then analyze_input_ref(expr)
            when Kumi::Core::NAST::Const        then analyze_const(expr)
            when Kumi::Core::NAST::Ref          then analyze_declaration_ref(expr)
            else
              raise "Unknown NAST node type: #{expr.class}"
            end
          end

          def analyze_call_expression(call, errors)
            function_spec = @function_specs.fetch(call.fn.to_s)

            arg_metadata = call.args.map { |arg| analyze_expression(arg, errors) }
            arg_types    = arg_metadata.map { |m| m[:type] }
            arg_scopes   = arg_metadata.map { |m| m[:scope] }

            if ENV['DEBUG_NAST_DIMENSIONAL_ANALYZER'] == '1' && function_spec.parameter_names.size != arg_types.size
              puts "[NASTDimensionalAnalyzer] WARNING: #{call.fn} expects #{function_spec.parameter_names.size} args, got #{arg_types.size}"
            end

            named_types =
              if function_spec.parameter_names.size == arg_types.size
                Hash[function_spec.parameter_names.zip(arg_types)]
              else
                { function_spec.parameter_names.first => arg_types } # variadic
              end

            result_type  = function_spec.dtype_rule.call(named_types)
            result_scope = compute_result_scope(function_spec, arg_scopes)

            needs_expand_flags =
              if [:elementwise, :constructor].include?(function_spec.kind)
                arg_scopes.map { |axes| axes != result_scope }
              end

            @metadata_table[node_id(call)] = {
              function:           function_spec.id,
              kind:               function_spec.kind,
              parameter_names:    function_spec.parameter_names,
              result_type:        result_type,
              result_scope:       result_scope,
              arg_types:          arg_types,
              arg_scopes:         arg_scopes,
              needs_expand_flags: needs_expand_flags,
              last_axis_token:    (function_spec.kind == :reduce ? (arg_scopes.first || []).last : nil)
            }.freeze

            debug "    Call #{function_spec.id}: (#{arg_types.join(', ')}) -> #{result_type} in #{result_scope.inspect}"
            { type: result_type, scope: result_scope }
          end

          def analyze_tuple_literal(tuple_literal, errors)
            elems           = tuple_literal.args.map { |e| analyze_expression(e, errors) }
            element_types   = elems.map { |m| m[:type] }
            element_scopes  = elems.map { |m| m[:scope] }
            result_scope    = lub_by_prefix(element_scopes)
            result_type     = "tuple<#{element_types.join(', ')}>"
            expand_flags    = element_scopes.map { |s| s != result_scope }

            @metadata_table[node_id(tuple_literal)] = {
              function:           :tuple_literal,
              kind:               :constructor,
              parameter_names:    [],
              result_type:        result_type,
              result_scope:       result_scope,
              arg_types:          element_types,
              arg_scopes:         element_scopes,
              needs_expand_flags: expand_flags,
              last_axis_token:    nil
            }.freeze

            debug "    Tuple: (#{element_types.join(', ')}) -> #{result_type} in #{result_scope.inspect}"
            { type: result_type, scope: result_scope }
          end

          # STRICT: requires entry with :axes and :dtype (no fallbacks)
          def analyze_input_ref(input_ref)
            entry = @input_table.find{|imp| imp[:path_fqn] == input_ref.path_fqn}
            entry or raise KeyError, "Input path not found in input_table: #{input_ref.path_fqn}"

            axes  = entry.axes
            dtype = entry.dtype

            { type: dtype, scope: axes }
          end

          def analyze_const(const)
            type =
              case const.value
              when Integer   then :integer
              when Float     then :float
              when String    then :string
              when true, false then :boolean
              else raise "Unknown constant type: #{const.value.class}"
              end
            { type: type, scope: [] }
          end

          def analyze_declaration_ref(ref)
            meta = @declaration_table.fetch(ref.name)
            @metadata_table[node_id(ref)] = {
              kind:            :ref,
              result_type:     meta[:result_type],
              result_scope:    meta[:result_scope],
              referenced_name: ref.name
            }.freeze
            { type: meta[:result_type], scope: meta[:result_scope] }
          end

          def compute_result_scope(function_spec, arg_scopes)
            case function_spec.kind
            when :elementwise, :constructor
              lub_by_prefix(arg_scopes)
            when :reduce
              child = arg_scopes.first || []
              child[0...-1]
            else
              []
            end
          end

          def lub_by_prefix(list)
            return [] if list.empty?
            candidate = list.max_by(&:length)
            list.each do |axes|
              unless axes.each_with_index.all? { |tok, i| candidate[i] == tok }
                raise Kumi::Core::Errors::SemanticError, "prefix mismatch: #{axes.inspect} vs #{candidate.inspect}"
              end
            end
            candidate
          end

          def node_id(node) = "#{node.class}_#{node.id}"
        end
      end
    end
  end
end
