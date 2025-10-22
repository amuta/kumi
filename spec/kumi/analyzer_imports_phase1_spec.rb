# frozen_string_literal: true

RSpec.describe "Analyzer Phase 1: Import Name Indexing" do
  include AnalyzerStateHelper

  after(:all) do
    # Clear cached instances
    MockSchemas::Tax.instance_variable_set(:@instance, nil)
    MockSchemas::Discount.instance_variable_set(:@instance, nil)
  end

  # Mock modules for testing
  module MockSchemas
    module Tax
      def self.kumi_schema_instance
        @instance ||= create_tax_schema
      end

      def self.create_tax_schema
        root_ast = Kumi::Core::RubyParser::Dsl.build_syntax_tree do
          input { decimal :amount }
          value :tax, input.amount * 0.15
          value :total, input.amount + tax
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
        schema_obj.instance_variable_set(:@analyzed_state, {})  # Empty for now, but represents full analysis
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
          value :rate, select(category > 5, 0.2, 0.1)
          value :discounted, price * (1.0 - rate)
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
        schema_obj.instance_variable_set(:@analyzed_state, {})  # Empty for now, but represents full analysis
        schema_obj
      end
    end
  end

  describe "NameIndexer with imports" do
    it "registers imported names in imported_declarations" do
      state = analyze_with_passes([Kumi::Core::Analyzer::Passes::NameIndexer]) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, ref(:result)
      end

      expect(state[:imported_declarations]).to have_key(:tax)
      expect(state[:imported_declarations][:tax]).to be_a(Hash)
      expect(state[:imported_declarations][:tax][:type]).to eq(:import)
    end

    it "stores import source module information" do
      state = analyze_with_passes([Kumi::Core::Analyzer::Passes::NameIndexer]) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, ref(:result)
      end

      import_meta = state[:imported_declarations][:tax]
      expect(import_meta[:from_module]).to eq(MockSchemas::Tax)
    end

    it "handles multiple imports from same module" do
      state = analyze_with_passes([Kumi::Core::Analyzer::Passes::NameIndexer]) do
        import :tax, :total, from: MockSchemas::Tax
        input { decimal :price }
        value :result, ref(:result)
      end

      expect(state[:imported_declarations]).to have_key(:tax)
      expect(state[:imported_declarations]).to have_key(:total)
      expect(state[:imported_declarations][:tax][:from_module]).to eq(MockSchemas::Tax)
      expect(state[:imported_declarations][:total][:from_module]).to eq(MockSchemas::Tax)
    end

    it "detects duplicate import + local declaration" do
      expect do
        analyze_with_passes([Kumi::Core::Analyzer::Passes::NameIndexer]) do
          import :tax, from: MockSchemas::Tax
          input { decimal :price }
          value :tax, input.price * 0.2
        end
      end.to raise_error(Kumi::Errors::AnalysisError, /duplicate/)
    end

    it "tracks local and imported declarations separately" do
      state = analyze_with_passes([Kumi::Core::Analyzer::Passes::NameIndexer]) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, input.price + 10
        value :discount, input.price * 0.1
      end

      expect(state[:imported_declarations]).to have_key(:tax)
      expect(state[:declarations]).to have_key(:result)
      expect(state[:declarations]).to have_key(:discount)

      expect(state[:imported_declarations][:tax][:type]).to eq(:import)
      expect(state[:declarations][:result]).to be_a(Kumi::Syntax::ValueDeclaration)
      expect(state[:declarations][:discount]).to be_a(Kumi::Syntax::ValueDeclaration)
    end
  end

  describe "ImportAnalysisPass" do
    it "loads source schema AST for imported declaration" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, ref(:result)
      end

      expect(state[:imported_schemas]).to have_key(:tax)
      expect(state[:imported_schemas][:tax]).to have_key(:decl)
      expect(state[:imported_schemas][:tax]).to have_key(:source_module)
      expect(state[:imported_schemas][:tax]).to have_key(:analyzed_state)
      expect(state[:imported_schemas][:tax][:source_module]).to eq(MockSchemas::Tax)
    end

    it "stores source declaration with rich analyzed data" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass
      ]

      state = analyze_with_passes(passes) do
        import :tax, from: MockSchemas::Tax
        input { decimal :price }
        value :result, ref(:result)
      end

      import_meta = state[:imported_schemas][:tax]
      source_decl = import_meta[:decl]
      expect(source_decl).to be_a(Kumi::Syntax::ValueDeclaration)
      expect(source_decl.name).to eq(:tax)

      # Check for rich analyzed data
      expect(import_meta).to have_key(:analyzed_state)
      expect(import_meta).to have_key(:input_metadata)
    end

    it "handles multiple imports" do
      passes = [
        Kumi::Core::Analyzer::Passes::NameIndexer,
        Kumi::Core::Analyzer::Passes::ImportAnalysisPass
      ]

      state = analyze_with_passes(passes) do
        import :tax, :total, from: MockSchemas::Tax
        input { decimal :price }
        value :result, ref(:result)
      end

      expect(state[:imported_schemas]).to have_key(:tax)
      expect(state[:imported_schemas]).to have_key(:total)
    end

    it "errors on imported name not found in source" do
      expect do
        passes = [
          Kumi::Core::Analyzer::Passes::NameIndexer,
          Kumi::Core::Analyzer::Passes::ImportAnalysisPass
        ]

        analyze_with_passes(passes) do
          import :nonexistent, from: MockSchemas::Tax
          input { decimal :price }
          value :result, ref(:result)
        end
      end.to raise_error(Kumi::Errors::AnalysisError)
    end
  end
end
