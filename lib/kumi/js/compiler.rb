# frozen_string_literal: true

module Kumi
  module Js
    # JavaScript compiler that extends the base Kumi compiler
    # Outputs JavaScript code instead of Ruby lambdas
    class Compiler < Kumi::Compiler
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
          path_js = path.map { |p| ".#{p}" }.join

          # Generate JavaScript function for nested field access
          "(ctx) => {\n  " \
            "const collection = ctx.#{path.first};\n  " \
            "if (!Array.isArray(collection)) return collection#{path_js[(path.first.to_s.length + 1)..]};\n  " \
            "return collection.map(item => {\n    " \
            "let current = item;\n    " \
            "#{path[1..].map { |segment| "current = current?.#{segment};" }.join("\n    ")}\n    " \
            "return current;\n  " \
            "});\n" \
            "}"
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

          # Check if this is a vectorized operation (reuse base compiler logic)
          if vectorized_operation?(expr)
            compile_vectorized_call(fn_name, arg_exprs, expr)
          else
            compile_regular_call(fn_name, arg_exprs, expr)
          end
        end

        def compile_cascade(expr)
          # Generate JavaScript cascade logic
          cases_js = expr.cases.map.with_index do |case_expr, i|
            condition_fn = compile_expr(case_expr.condition)
            result_fn = compile_expr(case_expr.result)

            "  const condition#{i} = #{condition_fn};\n  " \
              "const result#{i} = #{result_fn};\n  " \
              "if (condition#{i}(ctx)) return result#{i}(ctx);"
          end.join("\n")

          "(ctx) => {\n#{cases_js}\n  return null;\n}"
        end

        private

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
        when :es6
          generate_es6_module(bindings, **options)
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

      def generate_es6_module(bindings, **_options)
        # Generate ES6 module format
        functions_js = bindings.map do |name, meta|
          "  #{name}: #{meta[:function]}"
        end.join(",\n")

        <<~JAVASCRIPT
          // Generated by Kumi JavaScript Transpiler
          import { kumiRuntime, kumiRegistry } from './kumi-runtime.js';

          // Compiled Schema Bindings
          const bindings = {
          #{functions_js}
          };

          // Schema Runner
          export class KumiRunner {
            constructor(input) {
              this.input = input;
              this.cache = new Map();
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

          // Default export
          export default {
            from: (input) => new KumiRunner(input)
          };
        JAVASCRIPT
      end

      def js_runtime_code
        # JavaScript runtime with optimized function registry
        functions_required = @analysis.state[:functions_required] || Set.new
        <<~JAVASCRIPT
          // Function Registry
          #{FunctionRegistry.generate_js_code(functions_required: functions_required)}

          // Kumi Runtime for vectorized operations and utilities
          const kumiRuntime = {
            vectorizedCall: function(fnName, args) {
              const fn = kumiRegistry[fnName];
              if (!fn) throw new Error(`Unknown function: ${fnName}`);
          #{'    '}
              // Find arrays in arguments
              const arrays = args.filter(Array.isArray);
              if (arrays.length === 0) return fn(...args);
          #{'    '}
              const arrayLength = arrays[0].length;
              const result = [];
          #{'    '}
              for (let i = 0; i < arrayLength; i++) {
                const elementArgs = args.map(arg =>#{' '}
                  Array.isArray(arg) ? arg[i] : arg
                );
                result.push(fn(...elementArgs));
              }
          #{'    '}
              return result;
            }
          };
        JAVASCRIPT
      end
      
    end
  end
end
