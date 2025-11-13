# frozen_string_literal: true

require "json"
require "stringio"
require_relative "printer/irv2_formatter"

module Kumi
  module Dev
    module PrettyPrinter
      module_function

      def run(kind, path)
        method_name = "generate_#{kind}"
        raise "Unknown pretty print kind: #{kind}" unless respond_to?(method_name)

        output = send(method_name, path)
        puts output if output
      end

      def with_stop_after(pass_name)
        saved = {
          "KUMI_STOP_AFTER" => ENV.fetch("KUMI_STOP_AFTER", nil),
          "KUMI_CHECKPOINT" => ENV.fetch("KUMI_CHECKPOINT", nil),
          "KUMI_RESUME_FROM" => ENV.fetch("KUMI_RESUME_FROM", nil),
          "KUMI_RESUME_AT" => ENV.fetch("KUMI_RESUME_AT", nil)
        }

        ENV["KUMI_STOP_AFTER"] = pass_name
        ENV["KUMI_CHECKPOINT"] = "0"
        ENV.delete("KUMI_RESUME_FROM")
        ENV.delete("KUMI_RESUME_AT")

        yield
      ensure
        saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
      end

      def generate_ast(path)
        schema, = Kumi::Frontends.load(path: path)
        Kumi::Support::SExpressionPrinter.print(schema)
      end

      def generate_input_plan(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, return_with_state: :input_metadata)
        return nil unless res.state[:input_metadata]

        print_input_plan(res.state[:input_metadata])
      end

      def print_input_plan(metadata, indent = 0)
        lines = []
        metadata.each do |name, node|
          lines << format_node(name, node, indent)
        end
        lines.join("\n")
      end

      def format_node(name, node, indent)
        prefix = "  " * indent
        result = []

        # Node header with type and container
        header = "#{prefix}#{name}: #{node.type}"
        header += " (#{node.container})" if node.container != :scalar
        header += " access_mode=#{node.access_mode}" if node.access_mode
        result << header

        # Child steps if any
        if node.child_steps && !node.child_steps.empty?
          node.child_steps.each do |child_name, steps|
            steps_str = steps.map { |s| s[:kind] }.join(" → ")
            result << "#{prefix}  └─> #{child_name}: #{steps_str}"
          end
        end

        # Recursively print children
        if node.children && !node.children.empty?
          node.children.each do |child_name, child_node|
            result << format_node(child_name, child_node, indent + 1)
          end
        end

        result.join("\n")
      end

      def generate_ir(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:ir_module]

        Kumi::Support::IRRender.to_text(res.state[:ir_module], analysis_state: res.state)
      end

      def generate_nast(path)
        schema, = Kumi::Frontends.load(path: path)
        with_stop_after("NormalizeToNASTPass") do
          res = Kumi::Analyzer.analyze!(schema)
          return nil unless res.state[:nast_module]

          Kumi::Support::NASTPrinter.print(res.state[:nast_module])
        end
      end

      def generate_lir_00_unoptimized(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_00_unoptimized]

        Kumi::Support::LIRPrinter.print(res.state[:lir_00_unoptimized])
      end

      def generate_lir_01_hoist_scalar_references(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_01_hoist_scalar_references]

        Kumi::Support::LIRPrinter.print(res.state[:lir_01_hoist_scalar_references])
      end

      def generate_lir_02_inlined(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_02_inlined_ops_by_decl]

        Kumi::Support::LIRPrinter.print(res.state[:lir_02_inlined_ops_by_decl])
      end

      def generate_lir_04_1_loop_fusion(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_04_1_loop_fusion]

        Kumi::Support::LIRPrinter.print(res.state[:lir_04_1_loop_fusion])
      end

      def generate_lir_03_cse(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_03_cse]

        Kumi::Support::LIRPrinter.print(res.state[:lir_03_cse])
      end

      def generate_lir_04_loop_invcm(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_04_loop_invcm]

        Kumi::Support::LIRPrinter.print(res.state[:lir_04_loop_invcm])
      end

      def generate_lir_05_global_cse(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_05_global_cse]

        Kumi::Support::LIRPrinter.print(res.state[:lir_05_global_cse])
      end

      def generate_lir_06_const_prop(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        raise "Error Generating #{path}" unless res.state[:lir_06_const_prop]

        Kumi::Support::LIRPrinter.print(res.state[:lir_06_const_prop])
      end

      def generate_snast(path)
        schema, = Kumi::Frontends.load(path: path)
        with_stop_after("SNASTPass") do
          res = Kumi::Analyzer.analyze!(schema)
          raise "Error Generating #{path}" unless res.state[:snast_module]

          Kumi::Support::SNASTPrinter.print(res.state[:snast_module])
        end
      end

      def generate_dfir(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        snast = res.state[:snast_module] or raise "Missing SNAST for #{path}"
        registry = res.state[:registry] or raise "Missing registry for #{path}"
        input_table = res.state[:input_table] or raise "Missing input_table for #{path}"

        df_graph = Kumi::IR::DF::Lower.new(
          snast_module: snast,
          registry: registry,
          input_table: input_table
        ).call

        context = { registry:, input_table: }
        df_graph = Kumi::IR::DF::Pipeline.run(graph: df_graph, context: context)

        io = StringIO.new
        Kumi::IR::Printer.print(df_graph, io: io)
        io.string
      end

      def generate_irv2(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        return nil unless res.state[:irv2]

        Printer::WidthAwareJson.dump(res.state[:irv2])
      end

      def generate_binding_manifest(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        return nil unless res.state[:binding_manifest]

        Printer::WidthAwareJson.dump(res.state[:binding_manifest])
      end

      def generate_schema_ruby(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        return nil unless res.state[:ruby_codegen_files]

        res.state[:ruby_codegen_files]["codegen.rb"]
      end

      def generate_schema_javascript(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        return nil unless res.state[:javascript_codegen_files]

        res.state[:javascript_codegen_files]["codegen.mjs"]
      end

      def generate_planning(path)
        require_relative "../codegen/planning"

        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        return nil unless res.state[:irv2]

        bundle = Kumi::Codegen::Planning.from_ir(res.state[:irv2])
        planning_data = Kumi::Codegen::Planning.to_json(bundle)
        Printer::WidthAwareJson.dump(planning_data)
      end

      def generate_pack(path)
        require_relative "../pack"

        Kumi::Pack.print(schema: path, targets: %w[ruby])
      end
    end
  end
end
