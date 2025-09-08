# frozen_string_literal: true

require "json"
require_relative "printer/irv2_formatter"

module Kumi
  module Dev
    module PrettyPrinter
      module_function

      def run(kind, path)
        case kind
        when "ast" then print_ast(path)
        when "ir"  then print_ir(path)
        when "irv2" then print_irv2(path)
        when "nast" then print_nast(path)
        when "snast" then print_snast(path)
        when "planning" then print_planning(path)
        else
          abort "unknown representation: #{kind}"
        end
      end

      def print_ast(path)
        schema, = Kumi::Frontends.load(path: path)
        puts Kumi::Support::SExpressionPrinter.print(schema)
      end

      def print_ir(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        abort "No IR" unless res.state[:ir_module]
        puts Kumi::Support::IRRender.to_text(res.state[:ir_module], analysis_state: res.state)
      end

      def print_nast(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        abort "No NAST" unless res.state[:nast_module]
        puts Kumi::Support::NASTPrinter.print(res.state[:nast_module])
      end

      def print_snast(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        abort "No SNAST" unless res.state[:snast_module]
        puts Kumi::Support::SNASTPrinter.print(res.state[:snast_module])
      end

      def print_irv2(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema, side_tables: true)
        abort "No IRV2" unless res.state[:irv2]

        puts generate_irv2(path)
      end

      def print_planning(path)
        puts generate_planning(path)
      end

      # For golden testing - returns the output instead of printing
      def generate_ast(path)
        schema, = Kumi::Frontends.load(path: path)
        Kumi::Support::SExpressionPrinter.print(schema)
      end

      def generate_ir(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:ir_module]

        Kumi::Support::IRRender.to_text(res.state[:ir_module], analysis_state: res.state)
      end

      def generate_nast(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:nast_module]

        Kumi::Support::NASTPrinter.print(res.state[:nast_module])
      end

      def generate_lir(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:lir_ops_by_decl]

        Kumi::Support::LIRPrinter.print(res.state[:lir_ops_by_decl])
      end

      def generate_snast(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:snast_module]

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

      def generate_generated_code(path)
        require_relative "../pack/builder"
        require_relative "../codegen/ruby_v3/generator"

        # Generate pack using same approach as golden pack generation
        pack_json = Kumi::Pack::Builder.print(schema: path, targets: %w[ruby], include_ir: false)
        pack = JSON.parse(pack_json)
        
        # Generate code using Ruby V3 generator
        module_name = pack["module_id"].split('_').map(&:capitalize).join
        generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: module_name)
        generator.render
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
