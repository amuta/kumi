# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"

module Kumi
  module Pack
    module Builder
      VERSION = "0.1"

      module_function

      def build(schema:, out_dir:, targets: %w[ruby], include_ir: false)
        ir, planning, bindings, inputs, module_id = generate_artifacts(schema)
        FileUtils.mkdir_p(out_dir)
        write_json("#{out_dir}/irv2.json", ir)
        write_json("#{out_dir}/planning.json", planning)
        write_json("#{out_dir}/bindings.json", bindings)
        write_json("#{out_dir}/inputs.json", inputs)

        pack = assemble_pack(module_id, ir, planning, bindings, inputs, targets, include_ir)
        write_json("#{out_dir}/pack.json", pack)
        canonical_json(pack)
      end

      def print(schema:, targets: %w[ruby], include_ir: false)
        ir, planning, bindings, inputs, module_id = generate_artifacts(schema)
        pack = assemble_pack(module_id, ir, planning, bindings, inputs, targets, include_ir)
        canonical_json(pack)
      end

      def build_for_golden(schema_path, golden_dir, targets: %w[ruby])
        ir, planning, bindings, inputs, module_id = generate_artifacts(schema_path)
        
        targets.each do |target|
          pack = assemble_pack(module_id, ir, planning, bindings, inputs, [target], false)
          
          filename = targets.size == 1 ? "pack.json" : "pack_#{target}.json"
          pack_file = File.join(golden_dir, filename)
          File.write(pack_file, canonical_json(pack))
        end
      end

      def generate_artifacts(schema_path)
        schema, = Kumi::Frontends.load(path: schema_path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)

        irv2 = stringify_keys(res.state[:irv2]) or raise "No IRV2"
        module_id = irv2["module"] || irv2["module_id"] || "kumi_module"

        require_relative "../codegen/planning"
        plan_bundle = Kumi::Codegen::Planning.from_ir(res.state[:irv2])
        planning = Kumi::Codegen::Planning.to_json(plan_bundle)

        bindings = stringify_keys(res.state[:binding_manifest] || {})
        inputs = stringify_keys(res.state.dig(:analysis, :inputs) || [])

        [irv2, planning, bindings, inputs, module_id]
      end

      def assemble_pack(module_id, ir, planning, bindings, inputs, targets, include_ir)
        plan_obj = planning["plan"] || planning

        pack = {
          "pack_version" => VERSION,
          "module_id" => module_id,
          "plan" => plan_obj,
          "ops_by_decl" => extract_ops_by_decl(ir),
          "inputs" => extract_inputs(inputs),
          "bindings" => format_bindings_for_pack(bindings),
          "capabilities" => { "layout" => "nested_array" }
        }
        pack["ir_debug"] = ir if include_ir
        pack["hashes"] = compute_hashes(pack)
        pack
      end

      def extract_ops_by_decl(ir)
        declarations = ir["declarations"] || {}
        declarations.transform_values do |d|
          ops = (d["operations"] || []).map do |op|
            {
              "id" => op["id"],
              "op" => op["op"] || op["kind"],
              "args" => op["args"] || [],
              "attrs" => op["attrs"] || {}
            }
          end
          result = { "operations" => ops }
          result["result"] = d["result"] if d.key?("result")
          result["axes"] = d["axes"] if d.key?("axes")
          result
        end
      end

      def extract_inputs(inputs)
        Array(inputs).map do |inp|
          name = inp["name"] || Array(inp["path"]).join(".")
          {
            "name" => name,
            "axes" => inp["axes"] || [],
            "dtype" => inp["dtype"] || "unknown",
            "accessor_name" => accessor_name_for(name),
            "chain" => Array(inp["chain"]).map(&:to_s)
          }
        end
      end

      def format_bindings_for_pack(bindings)
        return {} unless bindings.is_a?(Hash)
        
        formatted = {}
        
        # Handle single binding manifest (not keyed by target)
        if bindings["target"] && bindings["kernels"]
          target = bindings["target"]
          kernels_array = bindings["kernels"].map do |kernel_id, impl|
            # Extract the function name from kernel_id (e.g., "core.add:ruby:v1" -> "core.add")
            fn_name = kernel_id.split(':').first
            # Format the implementation as proper Ruby lambda
            ruby_impl = format_ruby_lambda(impl)
            {
              "kernel_id" => fn_name,
              "impl" => ruby_impl
            }
          end
          formatted[target] = { "kernels" => kernels_array }
        else
          # Handle multiple binding manifests keyed by target
          bindings.each do |target, manifest|
            next unless manifest.is_a?(Hash) && manifest["kernels"]
            
            kernels_array = manifest["kernels"].map do |kernel_id, impl|
              fn_name = kernel_id.split(':').first
              ruby_impl = format_ruby_lambda(impl)
              {
                "kernel_id" => fn_name,
                "impl" => ruby_impl
              }
            end
            
            formatted[target] = { "kernels" => kernels_array }
          end
        end
        
        formatted
      end

      def format_ruby_lambda(impl)
        # Convert "(a, b)\n  a + b" to "->(a, b) { a + b }"
        lines = impl.strip.split("\n")
        if lines.length >= 2
          params = lines[0].strip.gsub(/^\(|\)$/, '')  # Remove outer parentheses
          body = lines[1..-1].map(&:strip).join("; ")
          "->(#{params}) { #{body} }"
        else
          # Fallback for single line
          "->(#{impl.strip})"
        end
      end

      def stringify_keys(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
        when Array
          obj.map { |v| stringify_keys(v) }
        else
          obj
        end
      end

      def accessor_name_for(name)
        name.gsub(/[^a-zA-Z0-9_]/, "_").downcase
      end

      def write_json(file_path, data)
        File.write(file_path, JSON.pretty_generate(data))
      end

      # Compute canonical section hashes (sorted-key JSON)
      def compute_hashes(pack)
        keys = %w[plan ops_by_decl inputs bindings]
        keys << "ir_debug" if pack.key?("ir_debug")
        keys.to_h { |k| [k, sha256(pack[k])] }
      end

      # Stable JSON for hashing
      def canonical_json(obj)
        case obj
        when Hash
          "{#{obj.keys.map(&:to_s).sort.map { |k| "\"#{k}\":#{canonical_json(obj[k])}" }.join(",")}}"
        when Array
          "[#{obj.map { |v| canonical_json(v) }.join(",")}]"
        when String   then JSON.generate(obj)
        when Numeric  then obj.to_s
        when true, false then obj.to_s
        when NilClass then "null"
        else JSON.generate(obj)
        end
      end

      def sha256(obj)
        Digest::SHA256.hexdigest(canonical_json(obj))
      end
    end
  end
end
