# frozen_string_literal: true

require "json"
require "open3"
require "bigdecimal"
require "tmpdir"

module Kumi
  module Dev
    # Executes a golden schema's generated Ruby AND JavaScript against its
    # input.json and returns a canonical JSON of the outputs — and, crucially,
    # asserts the two targets agree (Kumi's core bit-identical guarantee).
    #
    # Used by golden_v2's `runtime` representation: `update` snapshots the
    # outputs, `verify` re-runs and diffs (catching output regressions) while
    # also re-checking Ruby/JS parity. This is the execution coverage that the
    # old v1 golden RuntimeTest provided, folded into v2.
    module GoldenRuntime
      module_function

      JS_RUNNER = File.expand_path("support/kumi_runner.mjs", __dir__)

      # Returns a canonical JSON string of the schema's outputs, or nil if the
      # schema dir has no input.json (text-only golden). Raises on a Ruby/JS
      # mismatch or an execution error so verify surfaces it loudly.
      def snapshot(schema_path)
        dir = File.dirname(schema_path)
        input_file = File.join(dir, "input.json")
        return nil unless File.exist?(input_file)

        input = JSON.parse(File.read(input_file))
        schema, = Kumi::Frontends.load(path: schema_path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)

        decls = output_decl_names(res)
        ruby_out = run_ruby(res, input, decls)

        # JS parity is asserted EXACTLY (Kumi's bit-identical guarantee), except:
        #  - imports: JS needs generated shared modules (matches v1's skip).
        #  - decimals: `to_decimal` uses Ruby BigDecimal (exact) but JS has no
        #    decimal type and computes in float — a real, documented semantic gap,
        #    not a regression. We still snapshot the Ruby outputs for regression
        #    detection, but don't require Ruby == JS for these.
        parity_skipped =
          if schema_has_imports?(schema_path)
            "imports"
          elsif schema_uses_decimal?(schema_path)
            "decimal (Ruby BigDecimal vs JS float)"
          end

        unless parity_skipped
          js_out = run_js(res, input, decls, dir)
          assert_parity!(ruby_out, js_out, schema_path)
        end

        snapshot_with_note(ruby_out, parity_skipped)
      end

      def snapshot_with_note(ruby_out, parity_skipped)
        body = normalize(ruby_out)
        body = { "__ruby_js_parity_skipped" => parity_skipped, "outputs" => body } if parity_skipped
        JSON.pretty_generate(body)
      end

      def output_decl_names(res)
        # value declarations only (the schema's outputs).
        schema = res.state[:nast_module] || res.state[:snast_module]
        if schema.respond_to?(:decls)
          schema.decls.select { |_, d| d.respond_to?(:kind) ? d.kind == :value : true }.keys.map(&:to_s)
        else
          res.state[:ruby_codegen_files] ? extract_decls_from_ruby(res) : []
        end
      end

      def extract_decls_from_ruby(res)
        code = res.state[:ruby_codegen_files]["codegen.rb"]
        code.scan(/def self\._(\w+)\(/).flatten
      end

      def run_ruby(res, input, decls)
        code = res.state[:ruby_codegen_files]&.fetch("codegen.rb", nil)
        raise "no ruby codegen" unless code

        # Ensure the wrapper class (defined alongside Kumi::Schema) is loaded
        # before we reference it below.
        Kumi.const_get(:Schema)

        input = convert_decimal_strings(input)
        module_name = code.match(/module (Kumi::Compiled::\S+)/)[1]
        # eval defines the module if not already present; const_get either way.
        eval(code) unless Object.const_defined?(module_name) # rubocop:disable Security/Eval
        mod = Object.const_get(module_name)
        instance = Kumi::CompiledSchemaWrapper.new(mod, input)
        decls.to_h { |name| [name, instance[name.to_sym]] }
      end

      def run_js(res, input, decls, dir)
        code = res.state[:javascript_codegen_files]&.fetch("codegen.mjs", nil)
        raise "no javascript codegen" unless code
        raise "JS runner missing at #{JS_RUNNER}" unless File.exist?(JS_RUNNER)

        Dir.mktmpdir("golden_runtime_js") do |tmp|
          mod_path = File.join(tmp, "codegen.mjs")
          in_path  = File.join(tmp, "input.json")
          File.write(mod_path, code)
          File.write(in_path, JSON.generate(input))
          out, err, status = Open3.capture3("node", JS_RUNNER, mod_path, in_path, decls.join(","))
          raise "JS runner failed for #{dir}:\n#{err}" unless status.success?

          JSON.parse(out)
        end
      end

      def assert_parity!(ruby_out, js_out, schema_path)
        rk = canonical(ruby_out)
        jk = canonical(js_out)
        return if rk == jk

        raise "Ruby/JS output mismatch for #{schema_path}:\n  ruby: #{rk}\n  js:   #{jk}"
      end

      # Stable, normalized JSON: BigDecimals to floats, keys sorted, so snapshots
      # are deterministic and Ruby/JS compare equal.
      def canonical(value)
        JSON.pretty_generate(normalize(value))
      end

      def normalize(value)
        case value
        when Hash  then value.keys.sort_by(&:to_s).to_h { |k| [k.to_s, normalize(value[k])] }
        when Array then value.map { |v| normalize(v) }
        when BigDecimal then value.to_f
        # Ruby distinguishes 0.0 (Float) from 0 (Integer); JS does not, so an
        # integer-valued result serializes as "0.0" in Ruby and "0" from the JS
        # runner. Render every number as a Float so the two compare equal and the
        # snapshot is stable.
        when Numeric
          f = value.to_f
          f.zero? ? 0.0 : f # collapse -0.0 to 0.0 (JS prints both as 0)
        else value
        end
      end

      def convert_decimal_strings(value)
        case value
        when Hash  then value.transform_values { |v| convert_decimal_strings(v) }
        when Array then value.map { |v| convert_decimal_strings(v) }
        when String
          value.match?(/\A-?\d+(\.\d+)?\z/) ? BigDecimal(value) : value
        else value
        end
      end

      def schema_has_imports?(schema_path)
        File.exist?(schema_path) && File.read(schema_path).match?(/\bimport\s+/)
      end

      def schema_uses_decimal?(schema_path)
        File.exist?(schema_path) && File.read(schema_path).match?(/\bto_decimal\b|\bdecimal\b/)
      end
    end
  end
end
