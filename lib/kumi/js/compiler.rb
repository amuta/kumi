# frozen_string_literal: true

module Kumi
  module Js
    # JavaScript compiler that extends the base Kumi compiler
    # Outputs JavaScript code instead of Ruby lambdas
    class Compiler < Kumi::Core::CompilerBase
      # JavaScript expression compilers - same logic, different output format
      module JSExprCompilers
        def compile_literal(expr)
          value_js = case expr.value
                     when String
                       expr.value.inspect # Use inspect for proper escaping
                     when Numeric
                       expr.value.to_s
                     when TrueClass, FalseClass
                       expr.value.to_s
                     when NilClass
                       "null"
                     when Array
                       "[#{expr.value.map(&:inspect).join(', ')}]"
                     else
                       expr.value.inspect
                     end
          "(ctx) => #{value_js}"
        end

        def compile_field_node(expr)
          compile_field(expr)
        end

        def compile_element_field_reference(expr)
          path = expr.path

          # Check if we have nested paths metadata for this path
          nested_paths = @analysis.state[:broadcasts]&.dig(:nested_paths)
          unless nested_paths && nested_paths[path]
            raise Errors::CompilationError, "Missing nested path metadata for #{path.inspect}. This indicates an analyzer bug."
          end

          # Determine operation mode based on context
          operation_mode = determine_operation_mode_for_path(path)
          generate_js_nested_path_traversal(path, operation_mode)

          # ERROR: All nested paths should have metadata from the analyzer
          # If we reach here, it means the BroadcastDetector didn't process this path
        end

        def compile_binding_node(expr)
          name = expr.name
          # Reference to other compiled bindings
          "(ctx) => bindings.#{name}(ctx)"
        end

        def compile_list(expr)
          element_fns = expr.elements.map { |e| compile_expr(e) }

          # Generate JavaScript array creation
          elements_js = element_fns.map.with_index { |_, i| "  fn#{i}(ctx)" }.join(",\n")

          # Create function declarations for each element
          fn_declarations = element_fns.map.with_index do |fn_code, i|
            "  const fn#{i} = #{fn_code};"
          end.join("\n")

          "(ctx) => {\n#{fn_declarations}\n  return [\n#{elements_js}\n  ];\n}"
        end

        def compile_call(expr)
          fn_name = expr.fn_name
          arg_exprs = expr.args.map { |a| compile_expr(a) }

          # Get compilation metadata once
          compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)

          # Check if this is a vectorized operation
          if vectorized_operation?(expr)
            # Build vectorized executor JavaScript code
            compile_js_vectorized_call(fn_name, arg_exprs, compilation_meta)
          else
            # Use pre-computed function call strategy
            function_strategy = compilation_meta&.dig(:function_call_strategy) || {}

            if function_strategy[:flattening_required]
              compile_js_call_with_flattening(fn_name, arg_exprs, function_strategy)
            else
              compile_regular_call(fn_name, arg_exprs, expr)
            end
          end
        end

        def compile_cascade(expr)
          # Use metadata to determine if this cascade is vectorized
          if is_cascade_vectorized?(expr)
            compile_js_vectorized_cascade(expr)
          else
            compile_js_regular_cascade(expr)
          end
        end

        private

        def generate_js_nested_path_traversal(path, operation_mode)
          # Get path metadata to determine access mode (element vs object)
          nested_paths = @analysis.state[:broadcasts]&.dig(:nested_paths)
          path_metadata = nested_paths && nested_paths[path]
          access_mode = path_metadata&.dig(:access_mode) || :field

          if access_mode == :element
            # For element access, generate direct flattening based on path depth
            root_field = path.first
            flatten_depth = path.length - 1 # Flatten (path_depth - 1) levels

            if flatten_depth.positive?
              # Generate direct flat() call
              "(ctx) => ctx.#{root_field}.flat(#{flatten_depth})"
            else
              # No flattening needed
              "(ctx) => ctx.#{root_field}"
            end
          elsif path.length == 1
            # For object access, generate proper nested mapping
            # Simple field access
            "(ctx) => ctx.#{path.first}"
          elsif path.length == 2
            # Common case: array.field -> array.map(item => item.field)
            root_field, nested_field = path
            "(ctx) => ctx.#{root_field}.map(item => item.#{nested_field})"
          else
            # Complex nested object access - use the traversal
            path_js = "[#{path.map { |p| "'#{p}'" }.join(', ')}]"
            case operation_mode
            when :flatten
              "(ctx) => kumiRuntime.traverseNestedPath(ctx, #{path_js}, 'flatten', 'object')"
            else
              "(ctx) => kumiRuntime.traverseNestedPath(ctx, #{path_js}, 'broadcast', 'object')"
            end
          end
        end

        def compile_js_vectorized_call(fn_name, arg_exprs, compilation_meta)
          # Generate vectorized function call using metadata
          args_js = arg_exprs.map.with_index { |_, i| "arg#{i}(ctx)" }.join(", ")

          arg_declarations = arg_exprs.map.with_index do |arg_code, i|
            "  const arg#{i} = #{arg_code};"
          end.join("\n")

          # Convert compilation metadata to JSON string, handling nil case
          meta_json = compilation_meta ? compilation_meta.to_json : "null"

          "(ctx) => {\n#{arg_declarations}\n  return kumiRuntime.vectorizedFunctionCall('#{fn_name}', [#{args_js}], #{meta_json});\n}"
        end

        def compile_js_call_with_flattening(fn_name, arg_exprs, function_strategy)
          # Generate function call with selective argument flattening
          flatten_indices = function_strategy[:flatten_argument_indices] || []

          args_js = arg_exprs.map.with_index do |_, i|
            if flatten_indices.include?(i)
              "kumiRuntime.flattenCompletely(arg#{i}(ctx))"
            else
              "arg#{i}(ctx)"
            end
          end.join(", ")

          arg_declarations = arg_exprs.map.with_index do |arg_code, i|
            "  const arg#{i} = #{arg_code};"
          end.join("\n")

          fn_accessor = if fn_name.to_s.match?(/^[a-zA-Z_$][a-zA-Z0-9_$]*$/)
                          "kumiRegistry.#{fn_name}"
                        else
                          "kumiRegistry[\"#{fn_name}\"]"
                        end

          "(ctx) => {\n#{arg_declarations}\n  return #{fn_accessor}(#{args_js});\n}"
        end

        def compile_js_vectorized_cascade(expr)
          # Generate JavaScript vectorized cascade logic

          # Get pre-computed cascade strategy
          get_cascade_compilation_metadata
          strategy = get_cascade_strategy

          # Separate conditional cases from base case
          conditional_cases = expr.cases.select(&:condition)
          base_case = expr.cases.find { |c| c.condition.nil? }

          # Compile conditional pairs with vectorized condition handling
          condition_compilations = conditional_cases.map.with_index do |c, i|
            condition_fn = if is_cascade_vectorized?(expr)
                             compile_js_vectorized_condition(c.condition)
                           else
                             compile_expr(c.condition)
                           end
            "  const condition#{i} = #{condition_fn};"
          end.join("\n")

          result_compilations = conditional_cases.map.with_index do |c, i|
            result_fn = compile_expr(c.result)
            "  const result#{i} = #{result_fn};"
          end.join("\n")

          base_compilation = base_case ? "  const baseResult = #{compile_expr(base_case.result)};" : "  const baseResult = () => null;"

          # Convert strategy to JSON, handling symbols and complex objects
          strategy_json = if strategy
                            strategy.to_json
                          else
                            "null"
                          end

          <<~JAVASCRIPT
            (ctx) => {
            #{condition_compilations}
            #{result_compilations}
            #{base_compilation}
            #{'  '}
              const condResults = [#{conditional_cases.map.with_index { |_, i| "condition#{i}(ctx)" }.join(', ')}];
              const resResults = [#{conditional_cases.map.with_index { |_, i| "result#{i}(ctx)" }.join(', ')}];
              const baseRes = baseResult(ctx);
            #{'  '}
              return kumiRuntime.executeVectorizedCascade(condResults, resResults, baseRes, #{strategy_json});
            }
          JAVASCRIPT
        end

        def compile_js_regular_cascade(expr)
          # Generate standard JavaScript cascade logic
          cases_js = expr.cases.map.with_index do |case_expr, i|
            if case_expr.condition
              condition_fn = compile_expr(case_expr.condition)
              result_fn = compile_expr(case_expr.result)
              "  const condition#{i} = #{condition_fn};\n  " \
                "const result#{i} = #{result_fn};\n  " \
                "if (condition#{i}(ctx)) return result#{i}(ctx);"
            else
              # Base case
              result_fn = compile_expr(case_expr.result)
              "  const baseResult = #{result_fn};\n  " \
                "return baseResult(ctx);"
            end
          end.join("\n")

          "(ctx) => {\n#{cases_js}\n  return null;\n}"
        end

        def compile_js_vectorized_condition(condition_expr)
          if condition_expr.is_a?(Kumi::Syntax::CallExpression) &&
             condition_expr.fn_name == :cascade_and
            # For cascade_and in vectorized contexts, use hierarchical broadcasting
            compile_js_cascade_and_for_hierarchical_broadcasting(condition_expr)
          else
            # Otherwise compile normally
            compile_expr(condition_expr)
          end
        end

        def compile_js_cascade_and_for_hierarchical_broadcasting(condition_expr)
          # Compile individual trait references
          trait_compilations = condition_expr.args.map.with_index do |arg, i|
            trait_fn = compile_expr(arg)
            "  const trait#{i} = #{trait_fn};"
          end.join("\n")

          trait_args = condition_expr.args.map.with_index { |_, i| "trait#{i}(ctx)" }.join(", ")

          <<~JAVASCRIPT
            (ctx) => {
            #{trait_compilations}
              const traitValues = [#{trait_args}];
              return kumiRuntime.cascadeAndHierarchicalBroadcasting(traitValues);
            }
          JAVASCRIPT
        end

        def compile_regular_call(fn_name, arg_exprs, _expr)
          # Functions that expect spread arrays instead of array arguments
          spread_functions = %w[concat]

          # Generate function call with arguments
          args_js = if spread_functions.include?(fn_name.to_s) && arg_exprs.length == 1
                      # For spread functions with single array argument, spread the array
                      "...arg0(ctx)"
                    else
                      arg_exprs.map.with_index { |_, i| "arg#{i}(ctx)" }.join(", ")
                    end

          arg_declarations = arg_exprs.map.with_index do |arg_code, i|
            "  const arg#{i} = #{arg_code};"
          end.join("\n")

          # Handle function names that need bracket notation (operators with special chars)
          fn_accessor = if fn_name.to_s.match?(/^[a-zA-Z_$][a-zA-Z0-9_$]*$/)
                          "kumiRegistry.#{fn_name}"
                        else
                          "kumiRegistry[\"#{fn_name}\"]"
                        end

          "(ctx) => {\n#{arg_declarations}\n  return #{fn_accessor}(#{args_js});\n}"
        end

        def compile_vectorized_call(fn_name, arg_exprs, _expr)
          # Generate vectorized function call (broadcasting)
          args_js = arg_exprs.map.with_index { |_, i| "arg#{i}(ctx)" }.join(", ")

          arg_declarations = arg_exprs.map.with_index do |arg_code, i|
            "  const arg#{i} = #{arg_code};"
          end.join("\n")

          "(ctx) => {\n#{arg_declarations}\n  return kumiRuntime.vectorizedCall('#{fn_name}', [#{args_js}]);\n}"
        end

        def compile_field(node)
          name = node.name
          "(ctx) => {\n  " \
            "if (ctx.hasOwnProperty('#{name}')) return ctx.#{name};\n  " \
            "throw new Error(`Key '#{name}' not found. Available: ${Object.keys(ctx).join(', ')}`);\n" \
            "}"
        end
      end

      include JSExprCompilers

      def initialize(syntax_tree, analyzer_result)
        super
        @js_bindings = {}
      end

      def compile(**options)
        build_index

        # Compile each declaration to JavaScript
        @analysis.topo_order.each do |name|
          decl = @index[name] or raise("Unknown binding #{name}")
          compile_js_declaration(decl)
        end

        # Generate complete JavaScript module
        generate_js_module(@js_bindings, **options)
      end

      private

      def compile_js_declaration(decl)
        @current_declaration = decl.name
        kind = decl.is_a?(Kumi::Syntax::TraitDeclaration) ? :trait : :attr
        js_fn = compile_expr(decl.expression)
        @js_bindings[decl.name] = { type: kind, function: js_fn }
        @current_declaration = nil
      end

      def generate_js_module(bindings, format: :standalone, **options)
        case format
        when :standalone
          generate_standalone_js(bindings, **options)
        else
          raise ArgumentError, "Unknown format: #{format}"
        end
      end

      def generate_standalone_js(bindings, **options)
        # Generate a complete standalone JavaScript file
        functions_js = bindings.map do |name, meta|
          "  #{name}: #{meta[:function]}"
        end.join(",\n")

        <<~JAVASCRIPT
          // Generated by Kumi JavaScript Transpiler

          // Kumi Runtime and Function Registry
          #{js_runtime_code}

          // Compiled Schema Bindings
          const bindings = {
          #{functions_js}
          };

          // Schema Runner
          class KumiRunner {
            constructor(input) {
              this.input = input;
              this.cache = new Map();
              this.functionsUsed = [#{(@analysis.state[:functions_required] || Set.new).to_a.sort.map { |f| "\"#{f}\"" }.join(', ')}];
            }
          #{'  '}
            fetch(key) {
              if (this.cache.has(key)) {
                return this.cache.get(key);
              }
          #{'    '}
              if (!bindings[key]) {
                throw new Error(`Unknown binding: ${key}`);
              }
          #{'    '}
              const value = bindings[key](this.input);
              this.cache.set(key, value);
              return value;
            }
          #{'  '}
            slice(...keys) {
              const result = {};
              keys.forEach(key => {
                result[key] = this.fetch(key);
              });
              return result;
            }
          }

          // Export interface
          const schema = {
            from: (input) => new KumiRunner(input)
          };

          // CommonJS export
          if (typeof module !== 'undefined' && module.exports) {
            module.exports = { schema };
          }

          // Browser global
          if (typeof window !== 'undefined') {
            window.schema = schema;
            #{"window.#{options[:export_name]} = schema;" if options[:export_name]}
          }
        JAVASCRIPT
      end

      def js_runtime_code
        # JavaScript runtime with sophisticated broadcasting support
        functions_required = @analysis.state[:functions_required] || Set.new
        <<~JAVASCRIPT
          // Function Registry
          #{FunctionRegistry.generate_js_code(functions_required: functions_required)}

          // Enhanced Kumi Runtime for sophisticated vectorized operations
          const kumiRuntime = {
            // Nested path traversal matching Ruby implementation exactly
            traverseNestedPath: function(data, path, operationMode, accessMode = 'object') {
              let result;
          #{'    '}
              // Use specialized traversal for element access mode
              if (accessMode === 'element') {
                result = this.traverseElementPath(data, path, operationMode);
              } else {
                result = this.traversePathRecursive(data, path, operationMode, accessMode);
              }
          #{'    '}
              // Post-process result based on operation mode
              if (operationMode === 'flatten') {
                return this.flattenCompletely(result);
              }
              return result;
            },
          #{'  '}
            // Specialized traversal for element access mode (matches Ruby exactly)
            traverseElementPath: function(data, path, operationMode) {
              // Handle context wrapper by extracting the specific field
              if (data && typeof data === 'object' && !Array.isArray(data)) {
                const fieldName = path[0];
                const arrayData = data[fieldName];
          #{'      '}
                // Always apply progressive traversal based on path depth
                // This gives us the structure at the correct nesting level for both
                // broadcast operations and structure operations
                if (Array.isArray(arrayData) && path.length > 1) {
                  // Flatten exactly (path_depth - 1) levels to get the desired nesting level
                  return this.flattenToDepth(arrayData, path.length - 1);
                } else {
                  return arrayData;
                }
              } else {
                return data;
              }
            },
          #{'  '}
            // Flatten array to specific depth (matches Ruby array.flatten(n))
            flattenToDepth: function(arr, depth) {
              if (depth <= 0 || !Array.isArray(arr)) {
                return arr;
              }
          #{'    '}
              let result = arr.slice(); // Copy array
          #{'    '}
              for (let i = 0; i < depth; i++) {
                let hasNestedArrays = false;
                const newResult = [];
          #{'      '}
                for (const item of result) {
                  if (Array.isArray(item)) {
                    newResult.push(...item);
                    hasNestedArrays = true;
                  } else {
                    newResult.push(item);
                  }
                }
          #{'      '}
                result = newResult;
          #{'      '}
                // If no nested arrays found, no need to continue flattening
                if (!hasNestedArrays) {
                  break;
                }
              }
          #{'    '}
              return result;
            },
          #{'  '}
            traversePathRecursive: function(data, path, operationMode, accessMode = 'object', originalPathLength = null) {
              // Track original path length to determine traversal depth
              originalPathLength = originalPathLength || path.length;
              const currentDepth = originalPathLength - path.length;
          #{'    '}
              if (path.length === 0) return data;
          #{'    '}
              const field = path[0];
              const remainingPath = path.slice(1);
          #{'    '}
              if (remainingPath.length === 0) {
                // Final field - extract based on operation mode
                if (operationMode === 'broadcast' || operationMode === 'flatten') {
                  // Extract field preserving array structure
                  return this.extractFieldPreservingStructure(data, field, accessMode, currentDepth);
                } else {
                  // Simple field access
                  return Array.isArray(data) ?#{' '}
                    data.map(item => this.accessField(item, field, accessMode, currentDepth)) :#{' '}
                    this.accessField(data, field, accessMode, currentDepth);
                }
              } else if (Array.isArray(data)) {
                // Intermediate step - traverse deeper
                // Array of items - traverse each item
                return data.map(item =>#{' '}
                  this.traversePathRecursive(
                    this.accessField(item, field, accessMode, currentDepth),#{' '}
                    remainingPath,#{' '}
                    operationMode,#{' '}
                    accessMode,#{' '}
                    originalPathLength
                  )
                );
              } else {
                // Single item - traverse directly
                return this.traversePathRecursive(
                  this.accessField(data, field, accessMode, currentDepth),#{' '}
                  remainingPath,#{' '}
                  operationMode,#{' '}
                  accessMode,#{' '}
                  originalPathLength
                );
              }
            },
          #{'  '}
            extractFieldPreservingStructure: function(data, field, accessMode = 'object', depth = 0) {
              if (Array.isArray(data)) {
                return data.map(item => this.extractFieldPreservingStructure(item, field, accessMode, depth));
              } else {
                return this.accessField(data, field, accessMode, depth);
              }
            },
          #{'  '}
            accessField: function(data, field, accessMode, depth = 0) {
              if (accessMode === 'element') {
                // Element access mode - for nested arrays, we need to traverse one level deeper
                // This enables progressive path traversal like input.cube.layer.row.value
                if (data && typeof data === 'object' && !Array.isArray(data)) {
                  return data[field];
                } else if (Array.isArray(data)) {
                  // For element access, flatten one level to traverse deeper into nested structure
                  return this.flattenToDepth(data, 1);
                } else {
                  // If not an array, return as-is (leaf level)
                  return data;
                }
              } else {
                // Object access mode - normal hash/object field access
                return data[field];
              }
            },
          #{'  '}
            flattenCompletely: function(data) {
              const result = [];
              this.flattenRecursive(data, result);
              return result;
            },
          #{'  '}
            flattenRecursive: function(data, result) {
              if (Array.isArray(data)) {
                data.forEach(item => this.flattenRecursive(item, result));
              } else {
                result.push(data);
              }
            },
          #{'  '}
            // Sophisticated vectorized function call with metadata support
            vectorizedFunctionCall: function(fnName, args, compilationMeta) {
              const fn = kumiRegistry[fnName];
              if (!fn) throw new Error(`Unknown function: ${fnName}`);
          #{'    '}
              // Check if any argument is vectorized (array)
              const hasVectorizedArgs = args.some(Array.isArray);
          #{'    '}
              if (hasVectorizedArgs) {
                return this.vectorizedBroadcastingCall(fn, args, compilationMeta);
              } else {
                // All arguments are scalars - regular function call
                return fn(...args);
              }
            },
          #{'  '}
            vectorizedBroadcastingCall: function(fn, values, compilationMeta) {
              // Find array dimensions for broadcasting
              const arrayValues = values.filter(v => Array.isArray(v));
              if (arrayValues.length === 0) return fn(...values);
          #{'    '}
              // Check if we have deeply nested arrays (arrays containing arrays)
              const hasNestedArrays = arrayValues.some(arr =>#{' '}
                arr.some(item => Array.isArray(item))
              );
          #{'    '}
              if (hasNestedArrays) {
                return this.hierarchicalBroadcasting(fn, values);
              } else {
                return this.simpleBroadcasting(fn, values);
              }
            },
          #{'  '}
            simpleBroadcasting: function(fn, values) {
              const arrayValues = values.filter(v => Array.isArray(v));
              const arrayLength = arrayValues[0].length;
              const result = [];
          #{'    '}
              for (let i = 0; i < arrayLength; i++) {
                const elementArgs = values.map(arg =>
                  Array.isArray(arg) ? arg[i] : arg
                );
                result.push(fn(...elementArgs));
              }
          #{'    '}
              return result;
            },
          #{'  '}
            hierarchicalBroadcasting: function(fn, values) {
              // Handle hierarchical broadcasting for nested arrays
              const arrayValues = values.filter(v => Array.isArray(v));
              const maxDepthArray = arrayValues.reduce((max, arr) =>#{' '}
                this.calculateArrayDepth(arr) > this.calculateArrayDepth(max) ? arr : max
              );
          #{'    '}
              return this.mapNestedStructure(maxDepthArray, (indices) => {
                const elementArgs = values.map(arg =>#{' '}
                  this.navigateNestedIndices(arg, indices)
                );
                return fn(...elementArgs);
              });
            },
          #{'  '}
            calculateArrayDepth: function(arr) {
              if (!Array.isArray(arr)) return 0;
              return 1 + Math.max(0, ...arr.map(item => this.calculateArrayDepth(item)));
            },
          #{'  '}
            mapNestedStructure: function(structure, fn) {
              if (!Array.isArray(structure)) {
                return fn([]);
              }
          #{'    '}
              return structure.map((item, index) => {
                if (Array.isArray(item)) {
                  return this.mapNestedStructure(item, (innerIndices) =>#{' '}
                    fn([index, ...innerIndices])
                  );
                } else {
                  return fn([index]);
                }
              });
            },
          #{'  '}
            navigateNestedIndices: function(data, indices) {
              let current = data;
              for (const index of indices) {
                if (Array.isArray(current)) {
                  current = current[index];
                } else {
                  return current; // Scalar value - return as is
                }
              }
              return current;
            },
          #{'  '}
            // Vectorized cascade execution with strategy support
            executeVectorizedCascade: function(condResults, resResults, baseResult, strategy) {
              if (!strategy) {
                // Fallback to simple cascade evaluation
                for (let i = 0; i < condResults.length; i++) {
                  if (condResults[i]) return resResults[i];
                }
                return baseResult;
              }
          #{'    '}
              switch (strategy.mode) {
                case 'hierarchical':
                  return this.executeHierarchicalCascade(condResults, resResults, baseResult);
                case 'nested_array':
                case 'deep_nested_array':
                  return this.executeNestedArrayCascade(condResults, resResults, baseResult);
                case 'simple_array':
                  return this.executeSimpleArrayCascade(condResults, resResults, baseResult);
                default:
                  return this.executeScalarCascade(condResults, resResults, baseResult);
              }
            },
          #{'  '}
            executeHierarchicalCascade: function(condResults, resResults, baseResult) {
              // Find the result structure to use as template (deepest structure)
              const allValues = [...resResults, ...condResults, baseResult].filter(v => Array.isArray(v));
              const resultTemplate = allValues.reduce((max, v) =>#{' '}
                this.calculateArrayDepth(v) > this.calculateArrayDepth(max) ? v : max,#{' '}
                allValues[0] || []
              );
          #{'    '}
              if (!resultTemplate || !Array.isArray(resultTemplate)) {
                return this.executeScalarCascade(condResults, resResults, baseResult);
              }
          #{'    '}
              // Apply hierarchical cascade logic using the result structure as template
              return this.mapNestedStructure(resultTemplate, (indices) => {
                // Check conditional cases first with hierarchical broadcasting for conditions
                for (let i = 0; i < condResults.length; i++) {
                  const condVal = this.navigateWithHierarchicalBroadcasting(condResults[i], indices, resultTemplate);
                  if (condVal) {
                    const resVal = this.navigateNestedIndices(resResults[i], indices);
                    return resVal;
                  }
                }
          #{'      '}
                // If no conditions matched, use base result
                return this.navigateNestedIndices(baseResult, indices);
              });
            },
          #{'  '}
            navigateWithHierarchicalBroadcasting: function(value, indices, template) {
              // Navigate through value with hierarchical broadcasting to match template structure
              const valueDepth = this.calculateArrayDepth(value);
              const templateDepth = this.calculateArrayDepth(template);
          #{'    '}
              if (valueDepth < templateDepth) {
                // Value is at parent level - broadcast to child level by using fewer indices
                const parentIndices = indices.slice(0, valueDepth);
                return this.navigateNestedIndices(value, parentIndices);
              } else {
                // Same or deeper level - navigate normally
                return this.navigateNestedIndices(value, indices);
              }
            },
          #{'  '}
            executeNestedArrayCascade: function(condResults, resResults, baseResult) {
              // Handle nested array cascades with structure preservation
              const firstArrayResult = resResults.find(r => Array.isArray(r)) ||#{' '}
                                     condResults.find(c => Array.isArray(c)) ||#{' '}
                                     (Array.isArray(baseResult) ? baseResult : []);
          #{'    '}
              return this.mapNestedStructure(firstArrayResult, (indices) => {
                for (let i = 0; i < condResults.length; i++) {
                  const condVal = this.navigateNestedIndices(condResults[i], indices);
                  if (condVal) {
                    return this.navigateNestedIndices(resResults[i], indices);
                  }
                }
                return this.navigateNestedIndices(baseResult, indices);
              });
            },
          #{'  '}
            executeSimpleArrayCascade: function(condResults, resResults, baseResult) {
              // Handle simple array cascades (flat arrays)
              const arrayLength = Math.max(
                ...condResults.filter(Array.isArray).map(arr => arr.length),
                ...resResults.filter(Array.isArray).map(arr => arr.length),
                Array.isArray(baseResult) ? baseResult.length : 0
              );
          #{'    '}
              const result = [];
              for (let i = 0; i < arrayLength; i++) {
                let matched = false;
                for (let j = 0; j < condResults.length; j++) {
                  const condVal = Array.isArray(condResults[j]) ? condResults[j][i] : condResults[j];
                  if (condVal) {
                    const resVal = Array.isArray(resResults[j]) ? resResults[j][i] : resResults[j];
                    result[i] = resVal;
                    matched = true;
                    break;
                  }
                }
                if (!matched) {
                  result[i] = Array.isArray(baseResult) ? baseResult[i] : baseResult;
                }
              }
              return result;
            },
          #{'  '}
            executeScalarCascade: function(condResults, resResults, baseResult) {
              // Handle scalar cascades (no arrays involved)
              for (let i = 0; i < condResults.length; i++) {
                if (condResults[i]) return resResults[i];
              }
              return baseResult;
            },
          #{'  '}
            // Cascade AND with hierarchical broadcasting support
            cascadeAndHierarchicalBroadcasting: function(traitValues) {
              if (traitValues.length === 0) return true;
              if (traitValues.length === 1) return traitValues[0];
          #{'    '}
              // Use the cascade_and function directly on the array structures
              return kumiRegistry.cascade_and(...traitValues);
            },
          #{'  '}
            // Element-wise AND with hierarchical broadcasting (matches Ruby implementation)
            elementWiseAnd: function(a, b) {
              // Handle different type combinations
              if (Array.isArray(a) && Array.isArray(b)) {
                // Both are arrays - handle hierarchical broadcasting
                if (this.hierarchicalBroadcastingNeeded(a, b)) {
                  return this.performHierarchicalAnd(a, b);
                } else {
                  // Same structure - use zip for element-wise operations
                  return a.map((elemA, idx) => this.elementWiseAnd(elemA, b[idx]));
                }
              } else if (Array.isArray(a)) {
                // Broadcast scalar b to array a
                return a.map(elem => this.elementWiseAnd(elem, b));
              } else if (Array.isArray(b)) {
                // Broadcast scalar a to array b
                return b.map(elem => this.elementWiseAnd(a, elem));
              } else {
                // Both are scalars - simple AND
                return a && b;
              }
            },
          #{'  '}
            hierarchicalBroadcastingNeeded: function(a, b) {
              // Check if arrays have different nesting depths
              const depthA = this.calculateArrayDepth(a);
              const depthB = this.calculateArrayDepth(b);
              return depthA !== depthB;
            },
          #{'  '}
            performHierarchicalAnd: function(a, b) {
              // Determine which is parent (lower depth) and which is child (higher depth)
              const depthA = this.calculateArrayDepth(a);
              const depthB = this.calculateArrayDepth(b);
          #{'    '}
              if (depthA < depthB) {
                // a is parent, b is child
                return this.broadcastParentToChild(a, b);
              } else {
                // b is parent, a is child
                return this.broadcastParentToChild(b, a);
              }
            },
          #{'  '}
            broadcastParentToChild: function(parent, child) {
              // Map over child structure, broadcasting parent values appropriately
              return this.mapNestedStructure(child, (indices) => {
                // Navigate to appropriate parent element using fewer indices
                const parentIndices = indices.slice(0, this.calculateArrayDepth(parent));
                const parentValue = this.navigateNestedIndices(parent, parentIndices);
                const childValue = this.navigateNestedIndices(child, indices);
                return parentValue && childValue;
              });
            }
          };
        JAVASCRIPT
      end
    end
  end
end
