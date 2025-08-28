# frozen_string_literal: true

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
        res = Kumi::Analyzer.analyze!(schema)
        abort "No IRV2" unless res.state[:irv2_module]
        puts res.state[:irv2_module]
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

      def generate_snast(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:snast_module]

        Kumi::Support::SNASTPrinter.print(res.state[:snast_module])
      end

      def generate_irv2(path)
        schema, = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:irv2_module]

        res.state[:irv2_module].to_s
      end
    end
  end
end
