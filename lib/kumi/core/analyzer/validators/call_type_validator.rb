# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Validators
        # Encapsulates all call-level type checks for TypeCheckerV2 pass.
        # 
        # RESPONSIBILITIES:
        #   - Resolve functions via RegistryV2 using qualified names from CallNameNormalizePass
        #   - Compute result dtypes using function metadata and argument types
        #   - Validate argument type constraints (Numeric, Orderable, Bool, etc.)
        #   - Handle aggregate function element type unwrapping for constraint validation
        #   - Infer expression types using node metadata and analyzer state
        #   - Track function usage for downstream compilation
        #
        # CONSTRAINT VALIDATION:
        #   - For scalar functions: validates container type directly
        #   - For aggregate functions: validates element type (unwraps arrays)
        #   - Skips validation inside vectorized contexts to avoid double-checking
        #
        # STATE DEPENDENCIES:
        #   - node_index: CallExpression metadata with qualified_name and result_dtype
        #   - input_metadata: declared types for input field references  
        #   - inferred_types: computed types for declaration references
        #   - broadcasts: vectorization context for constraint skip logic
        class CallTypeValidator
          include Kumi::Core::ErrorReporting
          
          attr_reader :functions_required

          def initialize(registry_v2:, state:)
            @registry_v2 = registry_v2
            @state        = state
            @functions_required = Set.new
          end

          def compute_result_dtype!(node, errors)
            # Pull metadata for this node (set by earlier passes)
            idx = get_state(:node_index, required: true)
            entry = idx[node.object_id]
            raise "Missing node_index entry for CallExpression #{node.object_id}" unless entry
            
            meta = entry[:metadata]
            raise "Missing metadata for CallExpression #{node.object_id}" unless meta

            # Special escapes (e.g., cascade_and identity)
            return if meta[:skip_signature]

            # Resolve function name (prefer qualified from normalization pass)
            qualified = (meta[:qualified_name] || node.fn_name).to_s

            fn = resolve_or_error(qualified, node, errors)
            return unless fn # unknown/arity error already reported

            # Record usage
            @functions_required.add(fn.name)

            # Compute result dtype if not already set by FunctionSignaturePass
            if meta[:result_dtype].nil?
              result_dtype = compute_function_result_dtype(fn, node)
              if result_dtype
                meta[:result_dtype] = result_dtype
                if ENV["DEBUG_TYPE_CHECKER"]
                  puts "    Computed result dtype: #{fn.name} -> #{result_dtype}"
                end
              end
            elsif ENV["DEBUG_TYPE_CHECKER"]
              puts "    Using pre-computed result dtype: #{fn.name} -> #{meta[:result_dtype]}"
            end

            if ENV["DEBUG_TYPE_CHECKER"]
              puts "  TypeCheck pass1 call_id=#{node.object_id} qualified=#{fn.name} result_dtype=#{meta[:result_dtype]}"
            end
          end

          def validate_constraints!(node, errors)
            # Pull metadata for this node (set by earlier passes)
            idx = get_state(:node_index, required: true)
            entry = idx[node.object_id]
            raise "Missing node_index entry for CallExpression #{node.object_id}" unless entry
            
            meta = entry[:metadata]
            raise "Missing metadata for CallExpression #{node.object_id}" unless meta

            # Special escapes (e.g., cascade_and identity)
            return if meta[:skip_signature]

            # Resolve function name (prefer qualified from normalization pass)
            qualified = (meta[:qualified_name] || node.fn_name).to_s

            fn = resolve_or_error(qualified, node, errors)
            return unless fn # unknown/arity error already reported

            # Validate argument constraints (map args -> type_vars)
            validate_arg_constraints!(fn, node, meta, errors)

            debug_log(node, meta, fn) if ENV["DEBUG_TYPE_CHECKER"]
            
            if ENV["DEBUG_TYPE_CHECKER"]
              puts "  TypeCheck pass2 call_id=#{node.object_id} qualified=#{fn.name} constraints=validated"
            end
          end

          private

          def get_state(key, required: false)
            val = @state[key]
            if required && val.nil?
              raise "CallTypeValidator requires state[:#{key}] but it was not found. Available keys: #{@state.keys.inspect}"
            end
            val
          end

          def resolve_or_error(qualified, node, errors)
            @registry_v2.resolve(qualified, arity: node.args.size)
          rescue KeyError => e
            report_error(
              errors,
              "Unknown or incompatible function `#{qualified}` with arity #{node.args.size}: #{e.message}",
              location: node.loc, type: :type
            )
            nil
          end

          # --- Argument constraint checking -----------------------------------

          def validate_arg_constraints!(fn, node, meta, errors)
            tv = fn.respond_to?(:type_vars) ? (fn.type_vars || {}) : {}
            return if tv.empty?

            # Skip strict checks inside vectorized contexts if you've chosen to do so
            # (keep the same behavior you had before). Comment out to enforce strictly.
            bmeta = get_state(:broadcasts, required: false)
            return if vectorized_context?(node, bmeta)

            # Check if this is an aggregate function
            is_aggregate = aggregate_function?(fn)

            # Derive per-arg constraint by position (ordered YAML keys are stable)
            var_names = tv.keys
            node.args.each_with_index do |arg, i|
              var = var_names[i] || var_names.last
              constraint = tv[var]
              next if constraint.nil? || constraint.to_s.casecmp("Any").zero?

              raw_type = infer_expr_type(arg)
              
              # For aggregate functions, check the element type instead of the container type
              actual_type = is_aggregate ? element_type_of(raw_type) : raw_type
              
              next if satisfies_constraint?(actual_type, constraint)

              expected_desc = pretty_constraint(constraint)
              source_desc   = describe_expr(arg, raw_type) # Show original type in error message
              original_name = node.fn_name # show the user's surface name
              report_error(
                errors,
                "argument #{i + 1} of `fn(:#{original_name})` expects #{expected_desc}, got #{source_desc}",
                location: arg.loc, type: :type
              )
            end
          end

          def vectorized_context?(node, bmeta)
            return false unless bmeta && node.args
            node.args.any? do |arg|
              case arg
              when Kumi::Syntax::DeclarationReference
                bmeta[:vectorized_operations]&.key?(arg.name) ||
                  bmeta[:reduction_operations]&.key?(arg.name)
              when Kumi::Syntax::InputElementReference
                first = arg.respond_to?(:path) ? arg.path.first : nil
                first && bmeta[:array_fields]&.key?(first)
              else
                false
              end
            end
          end

          # --- Type inference for expressions --------------------------------

          def infer_expr_type(expr)
            case expr
            when Kumi::Syntax::Literal
              Kumi::Core::Types.infer_from_value(expr.value)

            when Kumi::Syntax::InputReference, Kumi::Syntax::InputElementReference
              input_meta = get_state(:input_metadata, required: true)
              if expr.respond_to?(:name) && input_meta[expr.name]
                input_meta[expr.name][:type] || :any
              elsif expr.respond_to?(:path)
                # Check if we have access_plans with flattened path metadata first
                access_plans = get_state(:access_plans, required: false)
                if access_plans
                  path_str = expr.path.join(".")
                  plans = access_plans[path_str]
                  if plans && !plans.empty?
                    # Extract type from access plan metadata if available
                    plan = plans.first
                    return plan.dig(:metadata, :type) || :any if plan.respond_to?(:dig)
                  end
                end
                
                # Fallback: navigate through nested input_metadata structure
                path = expr.path
                root_name = path.first
                
                root_meta = input_meta[root_name]
                return :any unless root_meta
                
                # Navigate through nested children metadata for arbitrary depth
                current_meta = root_meta
                path[1..-1].each do |segment|
                  current_meta = current_meta.dig(:children, segment)
                  return :any unless current_meta
                end
                
                current_meta[:type] || :any
              else
                :any
              end

            when Kumi::Syntax::DeclarationReference
              inferred = get_state(:inferred_types, required: true)
              inferred[expr.name] || :any

            when Kumi::Syntax::CallExpression
              # If a previous pass tagged the result dtype, use it
              idx = get_state(:node_index, required: true)
              entry = idx[expr.object_id]
              raise "Missing node_index entry for CallExpression #{expr.object_id}" unless entry
              
              md = entry[:metadata]
              raise "Missing metadata for CallExpression #{expr.object_id}" unless md
              
              result_dtype = md[:result_dtype]
              if result_dtype.nil?
                qualified = (md[:qualified_name] || expr.fn_name).to_s
                raise "Missing result_dtype for CallExpression #{expr.fn_name} (#{qualified}) at #{expr.loc}. " \
                      "This should have been set by TypeCheckerV2 before type inference. " \
                      "Available metadata: #{md.keys.inspect}"
              end
              result_dtype

            when Kumi::Syntax::ArrayExpression
              # Coarse: unify all element types
              elems = expr.elements
              raise "Missing elements for ArrayExpression" unless elems
              elems.map { |e| infer_expr_type(e) }.reduce(:any) { |acc, t| Kumi::Core::Types.unify(acc, t) }

            else
              :any
            end
          end

          # --- Result dtype computation -------------------------------------------

          def compute_function_result_dtype(fn, node)
            return nil unless fn.respond_to?(:dtypes) && fn.dtypes
            
            result_spec = fn.dtypes[:result] || fn.dtypes["result"]
            return nil unless result_spec
            
            # Build argument types for dtype computation
            arg_types = node.args.map { |arg| infer_expr_type(arg) }
            
            # Use DTypeAdapter to evaluate the result type
            Kumi::Core::Functions::DTypeAdapter.evaluate(fn, arg_types)
          rescue => e
            if ENV["DEBUG_TYPE_CHECKER"]
              puts "    Failed to compute result dtype for #{fn.name}: #{e.message}"
            end
            nil
          end

          def store_declaration_metadata!(decl_name, result_dtype)
            # Store inferred types in state for DeclarationReference lookups
            inferred_types = get_state(:inferred_types, required: true).dup
            inferred_types[decl_name] = result_dtype
            @state = @state.with(:inferred_types, inferred_types)
          end

          # --- Helper methods -------------------------------------------------

          def element_type_of(type)
            # Extract the element type from array container types
            # {:array => :float} -> :float
            # :float -> :float (passthrough)
            type.is_a?(Hash) && type[:array] ? type[:array] : type
          end

          def aggregate_function?(fn)
            # Check various ways the function class might be stored in RegistryV2
            (fn.respond_to?(:class_sym) && fn.class_sym.to_s == "aggregate") ||
            (fn.respond_to?(:class_name) && fn.class_name.to_s == "aggregate") ||
            (fn.respond_to?(:fn_class)   && fn.fn_class.to_s   == "aggregate") ||
            (fn.respond_to?(:klass)      && fn.klass.to_s      == "aggregate")
          end

          # --- Constraints ----------------------------------------------------

          def satisfies_constraint?(type, constraint)
            c = constraint.to_s.downcase

            case c
            when "any"         then true
            when "bool", "boolean"
              type == :boolean
            when "numeric"
              %i[integer float].include?(type)
            when "orderable"
              # Your policy (from earlier code): restrict to numeric orderables
              %i[integer float].include?(type)
            when "intlike"
              type == :integer
            when "stringlike"
              %i[string symbol].include?(type)
            when "datelike"
              %i[date datetime time].include?(type)
            else
              # Unknown constraint → permissive (or flip to false to be strict)
              true
            end
          end

          def pretty_constraint(constraint)
            case constraint.to_s.downcase
            when "numeric"    then "float"   # matches your historic error phrasing
            when "orderable"  then "float"   # ditto
            when "bool"       then "boolean"
            when "boolean"    then "boolean"
            when "intlike"    then "integer"
            when "stringlike" then "string"
            when "datelike"   then "date/datetime"
            else constraint.to_s
            end
          end

          # --- Messaging ------------------------------------------------------

          def describe_expr(expr, type)
            case expr
            when Kumi::Syntax::Literal
              "`#{expr.value}` of type #{type} (literal)"

            when Kumi::Syntax::InputReference
              "input field `#{expr.name}` of declared type #{type}"

            when Kumi::Syntax::InputElementReference
              leaf = expr.respond_to?(:path) ? Array(expr.path).join(".") : "input"
              "input path `#{leaf}` of declared type #{type}"

            when Kumi::Syntax::DeclarationReference
              "reference to declaration `#{expr.name}` of inferred type #{type}"

            when Kumi::Syntax::CallExpression
              "result of function `#{expr.fn_name}` returning #{type}"

            when Kumi::Syntax::ArrayExpression
              "array expression of type #{type}"

            else
              "expression of type #{type}"
            end
          end

          # Use inherited report_error from ErrorReporting mixin

          def debug_log(node, meta, fn)
            puts "  TypeCheck call_id=#{node.object_id} qualified=#{fn.name} " \
                 "fn_class=#{meta[:fn_class] || fn.class} status=validated"
          end
        end
      end
    end
  end
end