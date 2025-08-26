# frozen_string_literal: true

module Kumi
  module Dev
    module PrettyPrinter
      module_function

      def run(kind, path)
        case kind
        when "ast" then print_ast(path)
        when "ir"  then print_ir(path) 
        when "nir" then print_nir(path)
        else
          abort "unknown representation: #{kind}"
        end
      end

      def print_ast(path)
        schema, _ = Kumi::Frontends.load(path: path)
        puts Kumi::Support::SExpressionPrinter.print(schema)
      end

      def print_ir(path)
        schema, _ = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        abort "No IR" unless res.state[:ir_module]
        puts Kumi::Support::IRRender.to_text(res.state[:ir_module], analysis_state: res.state)
      end

      def print_nir(path)
        schema, _ = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        abort "No NIR" unless res.state[:nir_module]
        puts Kumi::Support::NIRPrinter.print(res.state[:nir_module])
      end

      # For golden testing - returns the output instead of printing
      def generate_ast(path)
        schema, _ = Kumi::Frontends.load(path: path)
        Kumi::Support::SExpressionPrinter.print(schema)
      end

      def generate_ir(path)
        schema, _ = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:ir_module]
        Kumi::Support::IRRender.to_text(res.state[:ir_module], analysis_state: res.state)
      end

      def generate_nir(path)
        schema, _ = Kumi::Frontends.load(path: path)
        res = Kumi::Analyzer.analyze!(schema)
        return nil unless res.state[:nir_module]
        Kumi::Support::NIRPrinter.print(res.state[:nir_module])
      end
    end
  end
end