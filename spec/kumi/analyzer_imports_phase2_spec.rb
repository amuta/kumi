# frozen_string_literal: true

RSpec.describe "Analyzer Phase 2: Import Dependency Resolution" do
  include AnalyzerStateHelper

  before(:each) do
    # Reset cached instances for each test to avoid pollution
    MockSchemas::Tax.instance_variable_set(:@instance, nil) if defined?(MockSchemas::Tax)
    MockSchemas::Discount.instance_variable_set(:@instance, nil) if defined?(MockSchemas::Discount)
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
            integer :category
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
        schema_obj.instance_variable_set(:@input_metadata, {price: {type: :decimal}, category: {type: :integer}})
        schema_obj.instance_variable_set(:@analyzed_state, {})
        schema_obj
      end
    end
  end

  describe "DependencyResolver with ImportCall nodes" do
    it "creates import_call dependency edge for simple ImportCall" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :total, fn(:tax, amount: input.price)
      end

      deps = state[:dependencies]
      expect(deps).to have_key(:total)

      import_edges = deps[:total].select { |e| e.type == :import_call }
      expect(import_edges).not_to be_empty
      expect(import_edges.first.to).to eq(:tax)
    end

    it "tracks input dependency from ImportCall mapping" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :total, fn(:tax, amount: input.price)
      end

      deps = state[:dependencies]

      key_edges = deps[:total].select { |e| e.type == :key }
      expect(key_edges).not_to be_empty
      expect(key_edges.first.to).to eq(:price)
    end

    it "handles ImportCall with multiple mapped inputs" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :discounted, from: MockSchemas::Discount
        input do
          decimal :price
          integer :category
        end
        value :final, fn(:discounted, price: input.price, category: input.category)
      end

      deps = state[:dependencies]

      import_edges = deps[:final].select { |e| e.type == :import_call }
      expect(import_edges.length).to eq(1)
      expect(import_edges.first.to).to eq(:discounted)

      key_edges = deps[:final].select { |e| e.type == :key }
      expect(key_edges.map(&:to)).to match_array([:price, :category])
    end

    it "handles ImportCall combined with local declaration reference" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :tax_amount, fn(:tax, amount: input.price)
        value :final, tax_amount + 100
      end

      deps = state[:dependencies]

      final_deps = deps[:final]
      ref_edges = final_deps.select { |e| e.type == :ref }
      expect(ref_edges.map(&:to)).to include(:tax_amount)
    end

    it "handles nested expressions in ImportCall mapping" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :adjusted, input.price * 1.1
        value :total, fn(:tax, amount: adjusted)
      end

      deps = state[:dependencies]

      total_deps = deps[:total]
      import_edges = total_deps.select { |e| e.type == :import_call }
      expect(import_edges).not_to be_empty

      ref_edges = total_deps.select { |e| e.type == :ref }
      expect(ref_edges.map(&:to)).to include(:adjusted)
    end

    it "handles ImportCall with nested expression in mapping" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :adjusted, input.price * 1.1
        value :total, fn(:tax, amount: adjusted)
      end

      deps = state[:dependencies]

      total_deps = deps[:total]
      import_edges = total_deps.select { |e| e.type == :import_call }
      expect(import_edges).not_to be_empty

      ref_edges = total_deps.select { |e| e.type == :ref }
      expect(ref_edges.map(&:to)).to include(:adjusted)
    end

    it "handles ImportCall that was marked as imported but not found in source" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      expect do
        analyze_with_passes(passes) do
          import :nonexistent, from: MockSchemas::Tax
          input { decimal :price }
          value :total, fn(:nonexistent, amount: input.price)
        end
      end.to raise_error(Kumi::Errors::AnalysisError)
    end

    it "handles multiple ImportCall nodes in same expression" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :with_tax, fn(:tax, amount: input.price)
        value :final, with_tax + 100
      end

      deps = state[:dependencies]

      final_deps = deps[:final]
      ref_edges = final_deps.select { |e| e.type == :ref }
      expect(ref_edges.map(&:to)).to include(:with_tax)

      with_tax_deps = deps[:with_tax]
      import_edges = with_tax_deps.select { |e| e.type == :import_call }
      expect(import_edges).not_to be_empty
      expect(import_edges.first.to).to eq(:tax)
    end

    it "distinguishes between ImportCall and regular CallExpression" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :doubled, input.price * 2
        value :total, fn(:tax, amount: input.price)
      end

      deps = state[:dependencies]

      doubled_deps = deps[:doubled]
      import_edges = doubled_deps.select { |e| e.type == :import_call }
      expect(import_edges).to be_empty

      total_deps = deps[:total]
      import_edges = total_deps.select { |e| e.type == :import_call }
      expect(import_edges).not_to be_empty
    end

    it "computes reverse dependencies including import_call edges" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :total, fn(:tax, amount: input.price)
      end

      dependents = state[:dependents]
      expect(dependents).to have_key(:tax)
      expect(dependents[:tax]).to include(:total)
    end

    it "preserves via information for ImportCall edges" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass,
        Kumi::Core::Analyzer::Passes::InputCollector,
        Kumi::Core::Analyzer::Passes::DependencyResolver
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :total, fn(:tax, amount: input.price)
      end

      deps = state[:dependencies]
      import_edges = deps[:total].select { |e| e.type == :import_call }
      expect(import_edges.first.via).to eq(:tax)
    end
  end
end
