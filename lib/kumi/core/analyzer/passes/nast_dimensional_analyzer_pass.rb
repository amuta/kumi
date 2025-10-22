# frozen_string_literal: true

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
            @registry = get_state(:registry, required: true)

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
            when Kumi::Core::NAST::Call         then analyze_call_expression(expr, errors)
            when Kumi::Core::NAST::ImportCall   then analyze_import_call(expr, errors)
            when Kumi::Core::NAST::Tuple        then analyze_tuple(expr, errors)
            when Kumi::Core::NAST::InputRef     then analyze_input_ref(expr)
            when Kumi::Core::NAST::IndexRef     then analyze_index_ref(expr, errors)
            when Kumi::Core::NAST::Const        then analyze_const(expr)
            when Kumi::Core::NAST::Pair         then analyze_pair(expr, errors)
            when Kumi::Core::NAST::Ref          then analyze_declaration_ref(expr)
            when Kumi::Core::NAST::Hash         then analyze_hash(expr, errors)

            else
              raise "Unknown NAST node type: #{expr.class}"
            end
          end

          def analyze_call_expression(call, errors)
            # Step 1: Analyze arguments to get their types and scopes
            arg_metadata = call.args.map { |arg| analyze_expression(arg, errors) }
            arg_types    = arg_metadata.map { |m| m[:type] }
            arg_scopes   = arg_metadata.map { |m| m[:scope] }

            # Ensure all arg_types are Type objects (defensive programming)
            arg_types = arg_types.map do |t|
              case t
              when Types::Type
                t
              when :array
                # :array is actually an ArrayType marker, not a scalar kind
                Types.array(Types.scalar(:any))
              when :hash
                Types.scalar(:hash)
              when Symbol
                # Try to normalize as scalar kind
                Types.normalize(t)
              else
                # Already a Type object or unknown format
                t
              end
            end

            debug "    Call #{call.fn}: arg_scopes=#{arg_scopes.inspect}, arg_types=#{arg_types.inspect}"

            # Step 2: Resolve function using type-aware overload resolution
            begin
              resolved_fn_id = @registry.resolve_function_with_types(call.fn.to_s, arg_types)
              function_spec = @registry.function(resolved_fn_id)
              debug "    Resolved '#{call.fn}' with types #{arg_types.inspect} to #{resolved_fn_id}"
            rescue Core::Functions::OverloadResolver::ResolutionError => e
              # Type-aware overload resolution failed - report with location
              report_type_error(
                errors,
                e.message,
                location: call.loc,
                context: {
                  function: call.fn.to_s,
                  arg_types: arg_types
                }
              )
              raise Kumi::Core::Errors::TypeError.new(e.message, call.loc)
            rescue StandardError => e
              # Other function resolution errors
              report_semantic_error(
                errors,
                "Function resolution error for '#{call.fn}': #{e.message}",
                location: call.loc,
                context: { function: call.fn.to_s }
              )
              raise Kumi::Core::Errors::SemanticError, e.message
            end

            # Step 3: Compute result type
            named_types =
              if function_spec.params.size == arg_types.size
                Hash[function_spec.param_names.zip(arg_types)]
              else
                { function_spec.param_names.first => arg_types } # variadic TODO: this is a hack
              end

            begin
              result_type = function_spec.dtype_rule.call(named_types)
            rescue StandardError => e
              report_type_error(
                errors,
                "Type rule evaluation failed for #{function_spec.id}: #{e.message}",
                location: call.loc,
                context: {
                  function: function_spec.id,
                  arg_types: arg_types
                }
              )
              raise Kumi::Core::Errors::TypeError, "Type rule failed for #{function_spec.id}: #{e.message}"
            end

            over_collection = arg_types.size == 1 && Types.collection?(arg_types[0])
            result_scope = compute_result_scope(function_spec, arg_scopes, over_collection)

            @metadata_table[node_id(call)] = {
              function: function_spec.id,
              kind: function_spec.kind,
              params: function_spec.params,
              result_type: result_type,
              result_scope: result_scope,
              arg_types: arg_types,
              arg_scopes: arg_scopes,
              last_axis_token: (function_spec.kind == :reduce ? (arg_scopes.first || []).last : nil) # TODO: REMOVE
            }.freeze

            debug "    Call #{function_spec.id}: (#{arg_types.join(', ')}) -> #{result_type} in #{result_scope.inspect}"
            { type: result_type, scope: result_scope }
          end

          def analyze_import_call(call, errors)
            # Analyze arguments
            arg_metadata = call.args.map { |arg| analyze_expression(arg, errors) }
            arg_types = arg_metadata.map { |m| m[:type] }
            arg_scopes = arg_metadata.map { |m| m[:scope] }

            # Get the imported schemas from state
            imported_schemas = get_state(:imported_schemas, required: false) || {}
            import_meta = imported_schemas[call.fn_name]

            unless import_meta
              report_error(errors, "imported function `#{call.fn_name}` not found", location: call.loc)
              return { type: Types.scalar(:any), scope: [] }
            end

            # Get the analyzed state of the source schema
            analyzed_state = import_meta[:analyzed_state]
            src_declaration_table = analyzed_state[:declaration_table] || {}

            # Look up the imported declaration in the source schema
            src_decl_meta = src_declaration_table[call.fn_name]
            unless src_decl_meta
              report_error(errors, "declaration `#{call.fn_name}` not found in imported schema", location: call.loc)
              return { type: Types.scalar(:any), scope: [] }
            end

            result_type = src_decl_meta[:result_type] || Types.scalar(:any)
            # ImportCall broadcasts over argument scopes (like elementwise functions)
            result_scope = lub_by_prefix(arg_scopes)

            @metadata_table[node_id(call)] = {
              kind: :import_call,
              result_type: result_type,
              result_scope: result_scope,
              imported_fn: call.fn_name,
              arg_types: arg_types,
              arg_scopes: arg_scopes
            }.freeze

            debug "    ImportCall #{call.fn_name}: -> #{result_type} in #{result_scope.inspect}"
            { type: result_type, scope: result_scope }
          end

          def analyze_tuple(node, errors)
            elems           = node.args.map { |e| analyze_expression(e, errors) }
            element_types   = elems.map { |m| m[:type] }
            element_scopes  = elems.map { |m| m[:scope] }
            result_scope    = lub_by_prefix(element_scopes)

            # Create TupleType from element Types
            result_type = Types.tuple(element_types)

            @metadata_table[node_id(node)] = {
              parameter_names: [],
              result_type: result_type,
              result_scope: result_scope,
              arg_types: element_types,
              arg_scopes: element_scopes,
              last_axis_token: nil
            }.freeze

            debug "    Tuple: (#{element_types.join(', ')}) -> #{result_type} in #{result_scope.inspect}"
            { type: result_type, scope: result_scope }
          end

          def analyze_hash(node, errors)
            fields = node.pairs.map { |e| analyze_expression(e, errors) }
            fields_scopes = fields.map { |m| m[:scope] }
            scope = lub_by_prefix(fields_scopes)
            dtype = Types.scalar(:hash)

            @metadata_table[node_id(node)] = {
              type: dtype,
              scope: scope
            }.freeze
          end

          def analyze_pair(node, errors)
            value_node = analyze_expression(node.value, errors)
            dtype = Types.scalar(:pair)

            @metadata_table[node_id(node)] = {
              type: dtype,
              scope: value_node[:scope]
            }.freeze
          end

          # STRICT: requires entry with :axes and :dtype (no fallbacks)
          def analyze_input_ref(input_ref)
            entry = @input_table.find { |imp| imp[:path_fqn] == input_ref.path_fqn }
            entry or raise KeyError, "Input path not found in input_table: #{input_ref.path_fqn}"

            axes  = entry.axes
            dtype = entry.dtype

            { type: dtype, scope: axes }
          end

          def analyze_const(node)
            type = Types.normalize(node.value.class)
            meta = { type: type, scope: [] }

            @metadata_table[node_id(node)] = meta
          end

          def analyze_index_ref(node, _errors)
            meta = @input_table.find { _1.path_fqn == node.input_fqn } or raise "Index plan found: #{n.name.inspect}"
            axes = Array(meta[:axes])
            type = Types.scalar(:integer)

            debug "    IndexRef #{node.name}: input_fqn=#{node.input_fqn}, axes=#{axes.inspect}"

            @metadata_table[node_id(node)] = { type:, scope: axes }.freeze
            { type:, scope: axes }
          end

          def analyze_declaration_ref(ref)
            meta = @declaration_table.fetch(ref.name)
            @metadata_table[node_id(ref)] = {
              kind: :ref,
              result_type: meta[:result_type],
              result_scope: meta[:result_scope],
              referenced_name: ref.name
            }.freeze
            { type: meta[:result_type], scope: meta[:result_scope] }
          end

          def compute_result_scope(function_spec, arg_scopes, over_collection = false)
            case function_spec.kind
            when :elementwise, :constructor
              lub_by_prefix(arg_scopes)
            when :reduce
              if over_collection
                lub_by_prefix(arg_scopes)
              else
                child = arg_scopes.first || []
                child[0...-1]
              end
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
