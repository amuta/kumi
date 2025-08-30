# frozen_string_literal: true

module Kumi
  module Codegen
    class RubyV2
      class Emitter
        def initialize(options)
          @options   = options
          @templates = TemplateLibrary.new(options)
          @selector  = TemplateSelector.new
        end

        def emit_program(declaration_plans, analysis)
          code = []
          code << emit_program_header
          code << emit_from_and_kernel
          code << emit_bound_header

          # dispatch: no memo, just call the method
          declaration_plans.each do |plan|
            code << %(        when :#{plan.name} then #{plan.name})
          end

          code << emit_bound_case_end
          code << emit_decl_methods(declaration_plans) # ← methods, not compute_*
          code << emit_accessors(analysis["inputs"])
          code << emit_footers
          code.join("\n")
        end

        private

        def emit_program_header
          <<~RUBY
            module Generated
              class Program
                def initialize(registry:, assertions: #{@options[:assertions]})
                  @registry   = registry
                  @assertions = assertions
                  @kern_cache = {}
                end
          RUBY
        end

        def emit_from_and_kernel
          <<~RUBY
            def from(data)
              Bound.new(self, data)
            end

            # Resolve registry entry to a callable:
            # - Proc/Method => use directly
            # - "Module::Path.method" => resolve constant chain and return .method(:method)
            # - otherwise, last-resort eval (must return an object responding to :call)
            def bind_kernel(id)
              @kern_cache[id] ||= begin
                impl = @registry.impl_for(id)

                case impl
                when Proc, Method
                  impl
                when String
                  if impl.include?('.') && impl.include?('::')
                    mod_path, meth = impl.split('.', 2)
                    mod = mod_path.split('::').inject(Object) { |m, c| m.const_get(c) }
                    mod.method(meth)
                  else
                    val = eval(impl)
                    unless val.respond_to?(:call)
                      raise "Registry impl for \#{id} did not resolve to a callable: \#{impl.inspect}"
                    end
                    val
                  end
                else
                  raise "Unsupported registry impl for \#{id}: \#{impl.class}"
                end
              end
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

        # one method per declaration (no memo)
        def emit_decl_methods(declaration_plans)
          out = []
          declaration_plans.each do |plan|
            out << ""
            out << "      def #{plan.name}"
            out << "        # ops: #{plan.operations.map { |o| "#{o[:id]}:#{o[:op_type]}" }.join(', ')}" if @options[:comments]

            plan.operations.each do |op|
              tpl  = @selector.select_template(op)
              code = @templates.emit_operation(op, tpl)
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
            lines << accessor_body(spec) # uses axes/chain to decide scalar vs array path
            lines << "      end"
          end
          lines.join("\n")
        end

        def accessor_name(path) = "fetch_#{path.join('_')}"

        def accessor_body(spec)
          chain      = spec["chain"]
          key_policy = spec["key_policy"] || "indifferent"
          on_missing = spec["on_missing"] || "error"

          # If there is any array_field in the chain, this accessor yields array-structured data
          vector_mode = chain.any? { |s| s["kind"] == "array_field" }

          lines = []
          cur   = "data"

          chain.each_with_index do |step, _idx|
            case step["kind"]
            when "array_field"
              key  = step["key"]
              get  = if key_policy == "indifferent"
                       "(#{cur}[:#{key}] || #{cur}[\"#{key}\"])"
                     else
                       "#{cur}[:#{key}]"
                     end
              miss = on_missing == "error" ? %( || (raise "Missing key: #{key}")) : ""
              lines << "        #{cur} = #{get}#{miss}"
            when "array_element"
              # lineage carrier — structure remains array; loops happen in Map/Reduce
              lines << "        raise \"Expected Array for array_element\" unless #{cur}.is_a?(Array)"
            when "scalar_leaf"
              key = step["key"]

              if vector_mode
                # We are inside an array context → map the leaf out of each element
                if key_policy == "indifferent"
                  lines << %(        #{cur} = #{cur}.map { |it| (it[:#{key}] || it["#{key}"])#{if on_missing == 'error'
                                                                                                 %( || (raise "Missing key: #{key}"))
                                                                                               end} })
                else
                  lines << %(        #{cur} = #{cur}.map { |it| it[:#{key}]#{if on_missing == 'error'
                                                                               %( || (raise "Missing key: #{key}"))
                                                                             end} })
                end
              else
                # Scalar accessor (no array_field in chain)
                get  = if key_policy == "indifferent"
                         "(#{cur}[:#{key}] || #{cur}[\"#{key}\"])"
                       else
                         "#{cur}[:#{key}]"
                       end
                miss = on_missing == "error" ? %( || (raise "Missing key: #{key}")) : ""
                lines << "        #{cur} = #{get}#{miss}"
              end
            else
              raise "Unknown chain step: #{step['kind']}"
            end
          end

          lines << "        #{cur}"
          lines.join("\n")
        end

        def emit_footers
          <<~RUBY
                end
              end
            end
          RUBY
        end
      end
    end
  end
end
