# frozen_string_literal: true

require "yaml"

module Kumi
  module FunctionRegistry
    # Reads the function/kernel YAML into the registry's record structs and
    # compiles each function's dtype rule. Every failure here is a malformed
    # registry data file, not user input, so they surface as CompilerBug.
    module Loader
      module_function

      Bug = Kumi::Core::Errors::CompilerBug

      # Build the result-type rule for a function from its YAML `dtype:` spec.
      # The spec is always a structured hash with a `rule` key naming one of the
      # rule builders in Types::DtypeRule.
      def build_dtype_rule_from_yaml(spec)
        raise Bug, "dtype spec must be a hash with a 'rule' key, got #{spec.inspect}" unless spec.is_a?(Hash)

        rules = Kumi::Core::Types::DtypeRule
        rule_type = spec.fetch("rule") { raise Bug, "dtype hash requires 'rule' key" }

        case rule_type
        when "same_as"
          rules.same_as(fetch_param(spec, "param"))
        when "promote"
          params = spec.fetch("params") { raise Bug, "promote rule requires 'params' key" }
          rules.promote(*Array(params).map(&:to_sym))
        when "element_of"
          rules.element_of(fetch_param(spec, "param"))
        when "unify"
          rules.unify(fetch_param(spec, "param1"), fetch_param(spec, "param2"))
        when "scalar"
          kind = spec.fetch("kind") { raise Bug, "scalar rule requires 'kind' key" }.to_sym
          raise Bug, "scalar rule has unknown kind: #{kind}" unless Kumi::Core::Types::Registry.kind?(kind)

          rules.scalar(kind)
        else
          raise Bug, "unknown dtype rule: #{rule_type}"
        end
      end

      def fetch_param(spec, key)
        spec.fetch(key) { raise Bug, "#{spec['rule']} rule requires '#{key}' key" }.to_sym
      end

      # { "core.mul" => Function(id: "core.mul", kind: :elementwise, params: [...]) }
      def load_functions(dir, func_struct)
        files = Dir.glob(File.join(dir, "**", "*.y{a,}ml"))
        funcs = files.flat_map { |p| (YAML.load_file(p) || {}).fetch("functions", []) }
        funcs.each_with_object({}) do |h, acc|
          f = func_struct.new(
            id: h.fetch("id").to_s,
            kind: h.fetch("kind").to_s.to_sym,
            aliases: Array(h["aliases"]).map!(&:to_s),
            params: h.fetch("params"),
            dtype: h["dtype"],
            expand: h["expand"],
            options: symbolize_keys(h["options"] || {}),
            folding_class_method: h["folding_class_method"],
            reduction_strategy: h["reduction_strategy"]&.to_sym
          )
          raise Bug, "duplicate function id `#{f.id}`" if acc.key?(f.id)

          acc[f.id] = f
        end
      end

      def symbolize_keys(hash)
        hash.transform_keys(&:to_sym)
      end

      # { ["core.mul", :ruby] => Kernel }
      def load_kernels(root, kernel_struct)
        targets = Dir.glob(File.join(root, "*")).select { |p| File.directory?(p) }.map { |p| File.basename(p).to_sym }
        out = {}
        targets.each do |t|
          Dir.glob(File.join(root, t.to_s, "**", "*.y{a,}ml")).each do |p|
            (YAML.load_file(p) || {}).fetch("kernels", []).each do |h|
              k = kernel_struct.new(
                id: h.fetch("id"),
                fn_id: h.fetch("fn").to_s,
                target: t,
                impl: h["impl"],
                identity: h["identity"],
                inline: h["inline"],
                fold_inline: h["fold_inline"]
              )
              key = [k.fn_id, t]
              raise Bug, "duplicate kernel for #{key}" if out.key?(key)

              out[key] = k
            end
          end
        end
        out
      end
    end
  end
end
