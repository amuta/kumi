# frozen_string_literal: true

require "json"
require_relative "name_mangler"
require_relative "runtime_snippets"
require_relative "kernels_emitter"
require_relative "chains_emitter"
require_relative "dispatcher_emitter"
require_relative "declaration_emitter"

module Kumi
  module Codegen
    module RubyV2
      class Generator
        def initialize(pack, module_name:)
          @pack        = deep_stringify(pack)
          @module_name = module_name
        end

        def render
          ms_inputs = Array(@pack.fetch("plan").fetch("module_spec").fetch("inputs"))
          declarations_array = @pack.fetch("declarations")
          decl_order = declarations_array.map { |d| d.fetch("name") }
          declarations = declarations_array.to_h { |d| [d.fetch("name"), d] }
          plan_decls = @pack.fetch("plan").fetch("declarations")
          bindings_ruby = (@pack.dig("bindings","ruby") || {})

          chains_src, chain_map = ChainsEmitter.render(plan_module_spec_inputs: @pack.fetch("inputs"))

          decls_src = +""
          decl_order.each do |name|
            decls_src << DeclarationEmitter.render_one(
              decl_name: name,
              decl_spec: declarations.fetch(name),
              plan_decl: plan_decls.fetch(name),
              chain_map: chain_map,
              ops_by_decl: declarations,
              all_plan_decls: plan_decls
            )
            decls_src << "\n"
          end

          dispatcher_src = DispatcherEmitter.render(declaration_order: decl_order)

          policy_map = @pack.dig("capabilities", "missing_policy") || {}
          runtime_src  = RuntimeSnippets.helpers_block(policy_map: policy_map)
          kernels_src  = KernelsEmitter.render(bindings_ruby: bindings_ruby)

          pack_hash = %w[plan declarations inputs bindings].map { |k| @pack.fetch("hashes").fetch(k) }.join(":")

          <<~RUBY
            # AUTOGEN: from kumi pack v#{@pack.fetch("pack_version")} — DO NOT EDIT
            
            module #{@module_name}
              PACK_HASH = #{pack_hash.inspect}.freeze

              class Program
                def self.from(data) = new(data)
                def initialize(data) = (@input = data; @memo = {})

            #{indent(dispatcher_src, 2)}

            #{indent(decls_src.rstrip, 2)}

            #{indent(runtime_src, 2)}
            #{indent(chains_src.rstrip, 2)}

            #{indent(kernels_src, 2)}
              end

              def self.from(data) = Program.new(data)
            end
          RUBY
        end

        private

        def deep_stringify(obj)
          case obj
          when Hash  then obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
          when Array then obj.map { |v| deep_stringify(v) }
          else obj
          end
        end

        def indent(str, n)
          pref = "  " * n
          str.split("\n").map { |l| pref + l }.join("\n")
        end
      end
    end
  end
end