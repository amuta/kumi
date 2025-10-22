# frozen_string_literal: true

RSpec.describe "Analyzer Phase 3: Import Type Analysis & Substitution" do
  include AnalyzerStateHelper

  after(:all) do
    # Clear cached instances
    MockSchemas::Tax.instance_variable_set(:@instance, nil)
    MockSchemas::Discount.instance_variable_set(:@instance, nil)
  end

  module MockSchemas
    module Tax
      def self.kumi_schema_instance
        @instance ||= create_tax_schema
      end

      def self.create_tax_schema
        root_ast = Kumi::Core::RubyParser::Dsl.build_syntax_tree do
          input { decimal :amount }
          value :tax, input.amount * 0.15
        end

        schema_obj = Object.new

        def schema_obj.root
          @root_ast
        end

        def schema_obj.input_metadata
          @input_metadata
        end

        def schema_obj.analyzed_state
          @analyzed_state
        end

        schema_obj.instance_variable_set(:@root_ast, root_ast)
        schema_obj.instance_variable_set(:@input_metadata, {amount: {type: :decimal}})
        schema_obj.instance_variable_set(:@analyzed_state, {})
        schema_obj
      end
    end

    module Discount
      def self.kumi_schema_instance
        @instance ||= create_discount_schema
      end

      def self.create_discount_schema
        root_ast = Kumi::Core::RubyParser::Dsl.build_syntax_tree do
          input do
            decimal :price
          end
          value :discounted, price * 0.9
        end

        schema_obj = Object.new

        def schema_obj.root
          @root_ast
        end

        def schema_obj.input_metadata
          @input_metadata
        end

        def schema_obj.analyzed_state
          @analyzed_state
        end

        schema_obj.instance_variable_set(:@root_ast, root_ast)
        schema_obj.instance_variable_set(:@input_metadata, {price: {type: :decimal}})
        schema_obj.instance_variable_set(:@analyzed_state, {})
        schema_obj
      end
    end
  end

  def normalize_to_nast_passes
    [
      Kumi::Core::Analyzer::Passes::NameIndexer,
      Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
      Kumi::Core::Analyzer::Passes::InputCollector,
      Kumi::Core::Analyzer::Passes::InputFormSchemaPass,
      Kumi::Core::Analyzer::Passes::DeclarationValidator,
      Kumi::Core::Analyzer::Passes::SemanticConstraintValidator,
      Kumi::Core::Analyzer::Passes::DependencyResolver,
      Kumi::Core::Analyzer::Passes::Toposorter,
      Kumi::Core::Analyzer::Passes::InputAccessPlannerPass,
      Kumi::Core::Analyzer::Passes::NormalizeToNASTPass
    ]
  end

  describe "NormalizeToNASTPass with ImportCall substitution" do
    it "substitutes ImportCall with source expression and maps inputs" do
      passes = normalize_to_nast_passes

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, fn(:tax, amount: input.price)
      end

      nast_module = state[:nast_module]
      result_decl = nast_module.decls[:result]

      expect(result_decl).to be_truthy
      expect(result_decl.body).to be_a(Kumi::Core::NAST::Call)
    end

    it "preserves input dependencies in substituted expression" do
      passes = normalize_to_nast_passes

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, fn(:tax, amount: input.price)
      end

      nast_module = state[:nast_module]
      result_decl = nast_module.decls[:result]

      input_refs = collect_input_refs(result_decl.body)
      expect(input_refs.map(&:path)).to include([:price])
    end

    it "handles ImportCall with multiple input mappings" do
      passes = normalize_to_nast_passes

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input do
          decimal :price
        end
        value :result, fn(:tax, amount: input.price)
      end

      nast_module = state[:nast_module]
      result_decl = nast_module.decls[:result]

      expect(result_decl).to be_truthy
      input_refs = collect_input_refs(result_decl.body)
      expect(input_refs.map(&:path)).to include([:price])
    end

    it "maintains expression structure through substitution" do
      passes = normalize_to_nast_passes

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :adjusted, input.price * 1.1
        value :result, fn(:tax, amount: adjusted)
      end

      nast_module = state[:nast_module]
      result_decl = nast_module.decls[:result]

      decl_refs = collect_declaration_refs(result_decl.body)
      expect(decl_refs.map(&:name)).to include(:adjusted)
    end

    it "no ImportCall nodes appear in NAST output" do
      passes = normalize_to_nast_passes

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, fn(:tax, amount: input.price)
      end

      nast_module = state[:nast_module]
      all_nodes = collect_all_nast_nodes(nast_module)

      import_calls = all_nodes.select { |n| n.is_a?(Kumi::Syntax::ImportCall) }
      expect(import_calls).to be_empty
    end

    it "handles nested expressions in ImportCall mapping" do
      passes = normalize_to_nast_passes

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input do
          decimal :base_price
          decimal :markup
        end
        value :result, fn(:tax, amount: input.base_price * input.markup)
      end

      nast_module = state[:nast_module]
      result_decl = nast_module.decls[:result]

      input_refs = collect_input_refs(result_decl.body)
      expect(input_refs.map(&:path)).to match_array([[:base_price], [:markup]])
    end
  end

  private

  def collect_input_refs(node, refs = [])
    case node
    when Kumi::Core::NAST::InputRef
      refs << node
    when Kumi::Core::NAST::Call
      node.args.each { |arg| collect_input_refs(arg, refs) }
    when Kumi::Core::NAST::Tuple
      node.args.each { |arg| collect_input_refs(arg, refs) }
    when Kumi::Core::NAST::Pair
      collect_input_refs(node.value, refs)
    when Kumi::Core::NAST::Hash
      node.pairs.each { |pair| collect_input_refs(pair, refs) }
    end
    refs
  end

  def collect_declaration_refs(node, refs = [])
    case node
    when Kumi::Core::NAST::Ref
      refs << node
    when Kumi::Core::NAST::Call
      node.args.each { |arg| collect_declaration_refs(arg, refs) }
    when Kumi::Core::NAST::Tuple
      node.args.each { |arg| collect_declaration_refs(arg, refs) }
    when Kumi::Core::NAST::Pair
      collect_declaration_refs(node.value, refs)
    when Kumi::Core::NAST::Hash
      node.pairs.each { |pair| collect_declaration_refs(pair, refs) }
    end
    refs
  end

  def collect_all_nast_nodes(node, nodes = [])
    nodes << node
    case node
    when Kumi::Core::NAST::Module
      node.decls.each { |_, decl| collect_all_nast_nodes(decl, nodes) }
    when Kumi::Core::NAST::Declaration
      collect_all_nast_nodes(node.body, nodes)
    when Kumi::Core::NAST::Call
      node.args.each { |arg| collect_all_nast_nodes(arg, nodes) }
    when Kumi::Core::NAST::Tuple
      node.args.each { |arg| collect_all_nast_nodes(arg, nodes) }
    when Kumi::Core::NAST::Pair
      collect_all_nast_nodes(node.value, nodes)
    when Kumi::Core::NAST::Hash
      node.pairs.each { |pair| collect_all_nast_nodes(pair, nodes) }
    end
    nodes
  end
end
