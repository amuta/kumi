# frozen_string_literal: true

require "json"
require_relative "printer/irv2_formatter"

module Kumi
  module Dev
    module PrettyPrinter
      module_function

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
        res = Kumi::Analyzer.analyze!(schema, return_with_state: :nast_module)
        return nil unless res.state[:nast_module]

        Kumi::Support::NASTPrinter.print(res.state[:nast_module])
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
        res = Kumi::Analyzer.analyze!(schema)
        raise "Error Generating #{path}" unless res.state[:snast_module]

        Kumi::Support::SNASTPrinter.print(res.state[:snast_module])
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

        res.state[:javascript_codegen_files]["codegen.js"]
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
