# frozen_string_literal: true

module Kumi
  module Codegen
    class Ruby
      class Emitter
        def initialize(options)
          @options      = options
          @templates    = TemplateLibrary.new(options)
          @selector     = TemplateSelector.new
          # { "core.mul:ruby:v1" => "->(a,b){ a * b }", ... }
          @kernel_impls = options[:kernel_impls] || {}
        end

        def emit_program(declaration_plans, analysis)
          kernel_ids = collect_kernel_ids(declaration_plans)

          code = []
          code << emit_program_header
          code << emit_from
          code << emit_bound_header

          # Dispatch
          declaration_plans.each do |plan|
            code << %(        when :#{plan.name} then #{plan.name})
          end

          code << emit_bound_case_end # inserts "private" section header

          # ---- kernels live INSIDE Bound (private) ----
          code << indent_block(emit_kernel_methods(kernel_ids), 6)

          # ---- declaration methods ----
          code << emit_decl_methods(declaration_plans)

          # ---- accessors ----
          code << emit_accessors(analysis["inputs"])

          code << emit_footers
          code.join("\n")
        end

        private

        def collect_kernel_ids(plans)
          plans.flat_map { |p| p.operations.map { |op| (op[:binding] || {})["kernel_id"] } }.compact.uniq
        end

        def emit_program_header
          <<~RUBY
            module Generated
              class Program
                def initialize(registry:, assertions: #{@options[:assertions]})
                  # registry kept for API compatibility; not used by inlined kernels
                  @registry   = registry
                  @assertions = assertions
                end
          RUBY
        end

        def emit_from
          <<~RUBY
            def from(data)
              Bound.new(self, data)
            end
          RUBY
        end

        def emit_bound_header
          <<~RUBY

            class Bound
              def initialize(program, data)
                @p = program
                @d = data
              end

              def [](decl)
                case decl
          RUBY
        end

        def emit_bound_case_end
          <<~RUBY
              else
                raise "Unknown declaration: \#{decl}"
              end
            end

            private
          RUBY
        end

        # ---------- Kernel inlining (now inside Bound) ----------
        def emit_kernel_methods(kernel_ids)
          kernel_ids.map do |kid|
            impl = @kernel_impls[kid]
            raise "No impl string for kernel #{kid.inspect} (expected manifest to provide 'impl')" unless impl.is_a?(String)

            sig_body = parse_lambda_string(impl) or raise(
              "Kernel impl for #{kid.inspect} is not a supported lambda/proc string: #{impl.inspect}.\n" \
              "Accepted forms: ->(a,b){ a + b }, ->(a,b) { a + b }, lambda { |a,b| a + b }, proc { |a,b| a + b }"
            )
            "def #{kernel_method_name(kid)}#{sig_body}\nend"
          end.join("\n\n")
        end

        # Must match TemplateLibrary
        def kernel_method_name(kid)
          "k_" + kid.gsub(/[^a-zA-Z0-9]+/, "_")
        end

        # Accept common lambda/proc forms, return "(args)\n  body"
        def parse_lambda_string(src)
          s = src.strip

          if m = s.match(/\A->\s*\(([^)]*)\)\s*\{\s*(.+)\s*\}\s*\z/m)
            args = m[1].strip
            body = m[2].strip
            return "(#{args})\n  #{body}"
          end

          if m = s.match(/\A->\s*\(([^)]*)\)\s*do\s*(.+)\s*end\s*\z/m)
            args = m[1].strip
            body = m[2].strip
            return "(#{args})\n  #{body}"
          end

          if m = s.match(/\A(?:lambda|proc)\s*\{\s*\|([^|]*)\|\s*(.+)\s*\}\s*\z/m)
            args = m[1].strip
            body = m[2].strip
            return "(#{args})\n  #{body}"
          end

          nil
        end

        # ---------- Declaration methods (inside Bound) ----------
        def emit_decl_methods(declaration_plans)
          out = []
          declaration_plans.each do |plan|
            out << ""
            out << "      def #{plan.name}"
            out << "        # ops: #{plan.operations.map { |o| "#{o[:id]}:#{o[:op_type]}" }.join(', ')}" if @options[:comments]

            ops_by_id = {}
            plan.operations.each { |o| ops_by_id[o[:id]] = o }

            plan.operations.each do |op|
              tpl  = @selector.select_template(op, ops_by_id)
              code = @templates.emit_operation(op, tpl, ops_by_id)
              next if code.empty?

              out << code.split("\n").map { |l| "        #{l}" }
            end

            out << "        op_#{plan.result_op_id}"
            out << "      end"
          end
          out.flatten.join("\n")
        end

        def emit_accessors(input_specs)
          lines = []
          input_specs.each do |spec|
            lines << ""
            lines << "      def #{accessor_name(spec['path'])}(data)"
            lines << accessor_body(spec)
            lines << "      end"
          end
          lines.join("\n")
        end

        def accessor_name(path) = "fetch_#{path.join('_')}"

        # Chain → code (depth-aware)
        def accessor_body(spec)
          chain      = spec["chain"] || []
          key_policy = (spec["key_policy"] || "indifferent").to_s
          on_missing = (spec["on_missing"] || "error").to_s

          lines = []
          cur   = "data"
          depth = 0

          chain.each do |step|
            case step["kind"]
            when "array_field"
              key = step["key"]
              if depth.zero?
                expr = indifferent_get_expr(cur, key, key_policy, on_missing)
                lines << "        #{cur} = #{expr}"
              else
                inner = indifferent_get_expr("it#{depth - 1}", key, key_policy, on_missing)
                lines << "        #{cur} = #{nested_map_expr(cur, depth, inner)}"
              end
              depth += 1

            when "array_element"
              depth += 1

            when "field_leaf"
              key = step["key"]
              if depth.zero?
                expr = indifferent_get_expr(cur, key, key_policy, on_missing)
                lines << "        #{cur} = #{expr}"
              else
                inner = indifferent_get_expr("it#{depth - 1}", key, key_policy, on_missing)
                lines << "        #{cur} = #{nested_map_expr(cur, depth, inner)}"
              end

            when "element_leaf", "scalar_leaf"
              # no-op

            else
              raise "Unknown chain step: #{step['kind']}"
            end
          end

          lines << "        #{cur}"
          lines.join("\n")
        end

        def indifferent_get_expr(receiver, key, key_policy, on_missing)
          expr = if key_policy == "indifferent"
                   "(#{receiver}[:#{key}] || #{receiver}[\"#{key}\"])"
                 else
                   "#{receiver}[:#{key}]"
                 end
          expr += %( || (raise "Missing key: #{key}")) if on_missing == "error"
          expr
        end

        def nested_map_expr(var, depth, inner_expr)
          return inner_expr if depth <= 0

          parts = []
          parts << "#{var}.map { |it0| "
          (1...depth).each { |lvl| parts << "it#{lvl - 1}.map { |it#{lvl}| " }
          parts << inner_expr
          parts << (" }" * depth)
          parts.join
        end

        def emit_footers
          <<~RUBY
                end
              end
            end
          RUBY
        end

        def indent_block(s, spaces)
          pad = " " * spaces
          s.split("\n").map { |l| pad + l }.join("\n")
        end
      end
    end
  end
end
