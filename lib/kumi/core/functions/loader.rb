# frozen_string_literal: true

require "yaml"
require_relative "function_spec"
require_relative "type_rules"

module Kumi
  module Core
    module Functions
      module Loader
        module_function

        def load_minimal_functions
          functions_root = File.expand_path("../../../../data/functions", __dir__)
          yaml_files = Dir.glob(File.join(functions_root, "**/*.yaml"))

          function_specs = {}
          yaml_files.each do |file|
            specs = load_file(file)
            specs.each { |spec| function_specs[spec.id] = spec }
          end

          function_specs
        end

        def load_file(file_path)
          doc = YAML.safe_load_file(file_path, permitted_classes: [], aliases: false) || {}
          (doc["functions"] || []).map { |fn_hash| build_function_spec(fn_hash) }
        end

        def build_function_spec(fn_hash)
          function_id = fn_hash.fetch("id")
          function_kind = fn_hash.fetch("kind").to_sym
          parameter_names = (fn_hash["params"] || []).map { |p| p["name"].to_sym }
          dtype_rule_fn = TypeRules.compile_dtype_rule(fn_hash.fetch("dtype"), parameter_names)

          FunctionSpec.new(
            id: function_id,
            kind: function_kind,
            parameter_names: parameter_names,
            dtype_rule: dtype_rule_fn
          )
        end
      end
    end
  end
end
