# frozen_string_literal: true

require "yaml"

module Kumi
  module RegistryV2
    module Loader
      module_function

      # Build dtype rule from YAML specification (structured or legacy string format)
      def build_dtype_rule_from_yaml(dtype_spec)
        case dtype_spec
        when String
          # Legacy string format: "same_as(x)", "promote(a,b)", "integer", etc.
          Kumi::Core::Functions::TypeRules.compile_dtype_rule(dtype_spec, [])
        when Hash
          # Structured format: { rule: 'same_as', param: 'x' }
          build_dtype_rule_from_hash(dtype_spec)
        else
          raise "Invalid dtype specification: #{dtype_spec.inspect}"
        end
      end

      # Build dtype rule from structured hash
      def build_dtype_rule_from_hash(spec)
        rule_type = spec.fetch("rule") { raise "dtype hash requires 'rule' key" }

        case rule_type
        when "same_as"
          param = spec.fetch("param") { raise "same_as rule requires 'param' key" }
          Kumi::Core::Functions::TypeRules.build_same_as(param.to_sym)

        when "promote"
          params = spec.fetch("params") { raise "promote rule requires 'params' key" }
          param_syms = Array(params).map { |p| p.to_sym }
          Kumi::Core::Functions::TypeRules.build_promote(*param_syms)

        when "element_of"
          param = spec.fetch("param") { raise "element_of rule requires 'param' key" }
          Kumi::Core::Functions::TypeRules.build_element_of(param.to_sym)

        when "unify"
          param1 = spec.fetch("param1") { raise "unify rule requires 'param1' key" }
          param2 = spec.fetch("param2") { raise "unify rule requires 'param2' key" }
          Kumi::Core::Functions::TypeRules.build_unify(param1.to_sym, param2.to_sym)

        when "common_type"
          param = spec.fetch("param") { raise "common_type rule requires 'param' key" }
          Kumi::Core::Functions::TypeRules.build_common_type(param.to_sym)

        when "array"
          if spec.key?("element_type")
            element_type_spec = spec["element_type"]
            element_type = if element_type_spec.is_a?(Hash)
                             # Nested structured format
                             build_dtype_rule_from_hash(element_type_spec).call({})
                           else
                             # String or symbol
                             element_type_spec.to_sym
                           end
            Kumi::Core::Functions::TypeRules.build_array(element_type)
          elsif spec.key?("element_type_param")
            element_type_param = spec["element_type_param"].to_sym
            Kumi::Core::Functions::TypeRules.build_array(element_type_param)
          else
            raise "array rule requires either 'element_type' or 'element_type_param' key"
          end

        when "tuple"
          if spec.key?("element_types")
            element_types_spec = spec["element_types"]
            element_types = Array(element_types_spec).map do |et|
              if et.is_a?(Hash)
                build_dtype_rule_from_hash(et).call({})
              else
                et.to_sym
              end
            end
            Kumi::Core::Functions::TypeRules.build_tuple(*element_types)
          elsif spec.key?("element_types_param")
            element_types_param = spec["element_types_param"].to_sym
            Kumi::Core::Functions::TypeRules.build_tuple(element_types_param)
          else
            raise "tuple rule requires either 'element_types' or 'element_types_param' key"
          end

        when "scalar"
          kind = spec.fetch("kind") { raise "scalar rule requires 'kind' key" }
          kind_sym = kind.to_sym
          raise "scalar rule has unknown kind: #{kind}" unless Kumi::Core::Types::Validator.valid_kind?(kind_sym)

          Kumi::Core::Functions::TypeRules.build_scalar(kind_sym)

        else
          raise "unknown dtype rule: #{rule_type}"
        end
      end

      # { "core.mul" => Function(id: "core.mul", kind: :elementwise, params: [...]) }
      def load_functions(dir, func_struct)
        files = Dir.glob(File.join(dir, "**", "*.y{a,}ml")).sort
        funcs = files.flat_map { |p| (YAML.load_file(p) || {}).fetch("functions", []) }
        # funcs.each_with_object({}) do |h, acc|
        #   acc[h.fetch("id").to_s] = {
        #     kind: h.fetch("kind").to_s.to_sym,
        #     aliases: Array(h["aliases"]).map!(&:to_s),
        #     params: h.fetch("params")
        #   }
        # end
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
          raise "duplicate function id `#{f.id}`" if acc.key?(f.id)

          acc[f.id] = f
        end
      end

      def symbolize_keys(h)
        h.each_with_object({}) { |(k, v), out| out[k.to_sym] = v }
      end

      def deep_symbolize_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), out| out[k.to_sym] = deep_symbolize_keys(v) }
        when Array
          obj.map { |v| deep_symbolize_keys(v) }
        else
          obj
        end
      end

      # { ["core.mul", :ruby] => Kernel }
      def load_kernels(root, kernel_struct)
        targets = Dir.glob(File.join(root, "*")).select { |p| File.directory?(p) }.map { |p| File.basename(p).to_sym }
        out = {}
        targets.each do |t|
          Dir.glob(File.join(root, t.to_s, "**", "*.y{a,}ml")).sort.each do |p|
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
              raise "duplicate kernel for #{key}" if out.key?(key)

              out[key] = k
            end
          end
        end
        out
      end
    end
  end
end
