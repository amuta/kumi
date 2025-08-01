# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::VisitorPass do
  include ASTFactory

  # Create a concrete test pass to test the visitor functionality
  let(:test_visitor_pass_class) do
    Class.new(described_class) do
      attr_reader :visited_nodes, :visited_expressions

      def self.contract
        Kumi::Core::Analyzer::PassContract.new
      end

      def initialize(schema, state)
        super
        @visited_nodes = []
        @visited_expressions = []
      end

      def run(errors)
        # Test the visitor methods
        visit_all_expressions(errors) do |node, decl, _errs|
          @visited_expressions << [node.class.name, decl.name]
        end

        visit_nodes_of_type(Kumi::Core::Syntax::Literal,
                            Kumi::Core::Syntax::CallExpression,
                            errors: errors) do |node, decl, _errs|
          @visited_nodes << [node.class.name, decl.name]
        end
        state
      end
    end
  end

  let(:schema) do
    # Create a schema with varied expression types for testing
    simple_attr = attr(:simple, lit(42))
    call_attr = attr(:calc, call(:add, lit(10), field_ref(:user_input)))
    ref_attr = attr(:ref_test, ref(:simple))
    complex_trait = trait(:complex, call(:and,
                                         call(:>, field_ref(:price), lit(100)),
                                         call(:==, field_ref(:active), lit(true))))

    syntax(:root, [], [simple_attr, call_attr, ref_attr], [complex_trait], loc: loc)
  end

  let(:state) { Kumi::Core::Analyzer::AnalysisState.new }
  let(:errors) { [] }
  let(:pass_instance) { test_visitor_pass_class.new(schema, state) }

  describe "#visit" do
    let(:test_node) do
      # Create a nested structure: call(add, lit(5), call(multiply, lit(2), lit(3)))
      call(:add, lit(5), call(:multiply, lit(2), lit(3)))
    end

    it "visits all nodes in depth-first order" do
      visited = []
      pass_instance.send(:visit, test_node) { |node| visited << node.class.name.split("::").last }

      # Should visit: CallExpression(add) -> Literal(5) -> CallExpression(multiply) -> Literal(2) -> Literal(3)
      expect(visited).to eq(%w[CallExpression Literal CallExpression Literal Literal])
    end

    it "handles nil nodes gracefully" do
      visited = []
      pass_instance.send(:visit, nil) { |node| visited << node }

      expect(visited).to be_empty
    end

    it "yields each node to the block" do
      yielded_nodes = []
      pass_instance.send(:visit, test_node) { |node| yielded_nodes << node }

      expect(yielded_nodes.size).to eq(5)
      expect(yielded_nodes.first).to be_a(Kumi::Core::Syntax::CallExpression)
      expect(yielded_nodes.last).to be_a(Kumi::Core::Syntax::Literal)
    end
  end

  describe "#visit_all_expressions" do
    it "visits expressions from all declarations" do
      pass_instance.run(errors)

      visited_expressions = pass_instance.visited_expressions

      # Should have visited expressions from all 4 declarations
      declaration_names = visited_expressions.map(&:last).uniq
      expect(declaration_names).to contain_exactly(:simple, :calc, :ref_test, :complex)
    end

    it "passes declaration context to block" do
      visited_with_context = []

      pass_instance.send(:visit_all_expressions, errors) do |node, decl, _errs|
        visited_with_context << { node_type: node.class.name.split("::").last,
                                  decl_name: decl.name,
                                  decl_type: decl.class.name.split("::").last }
      end

      # Verify we get both attributes and traits (using new class names)
      decl_types = visited_with_context.map { |v| v[:decl_type] }.uniq
      expect(decl_types).to contain_exactly("ValueDeclaration", "TraitDeclaration")
    end

    it "handles empty schema" do
      empty_schema = syntax(:root, [], [], [], loc: loc)
      empty_pass = test_visitor_pass_class.new(empty_schema, state)

      visited = []
      empty_pass.send(:visit_all_expressions, errors) { |node, _decl, _errs| visited << node }

      expect(visited).to be_empty
    end
  end

  describe "#visit_nodes_of_type" do
    it "only visits nodes of specified types" do
      pass_instance.run(errors)

      visited_nodes = pass_instance.visited_nodes
      node_types = visited_nodes.map(&:first).uniq

      # Should only have Literal and CallExpression nodes, not Field or Binding (using new class names)
      expect(node_types).to contain_exactly("Kumi::Core::Syntax::Literal", "Kumi::Core::Syntax::CallExpression")
    end

    it "visits nodes across all declarations" do
      pass_instance.run(errors)

      visited_nodes = pass_instance.visited_nodes
      declaration_names = visited_nodes.map(&:last).uniq

      # Should find matching node types in all declarations that have them
      expect(declaration_names).to include(:simple, :calc, :complex)
    end

    it "handles single node type" do
      visited_literals = []

      pass_instance.send(:visit_nodes_of_type,
                         Kumi::Core::Syntax::Literal,
                         errors: errors) do |node, decl, _errs|
        visited_literals << [node.value, decl.name]
      end

      # Should find all literal values
      literal_values = visited_literals.map(&:first)
      expect(literal_values).to include(42, 10, 100, true)
    end

    it "handles multiple node types" do
      visited_mixed = []

      pass_instance.send(:visit_nodes_of_type,
                         Kumi::Core::Syntax::InputReference,
                         Kumi::Core::Syntax::DeclarationReference,
                         errors: errors) do |node, decl, _errs|
        visited_mixed << [node.class.name.split("::").last, node.name, decl.name]
      end

      # Should find both FieldRef and Binding nodes (using new class names)
      node_types = visited_mixed.map(&:first).uniq
      expect(node_types).to include("InputReference", "DeclarationReference")
    end

    it "handles non-matching node types gracefully" do
      visited_none = []

      # Look for a node type that doesn't exist in our schema
      pass_instance.send(:visit_nodes_of_type,
                         String, # This won't match any syntax nodes
                         errors: errors) do |node, _decl, _errs|
        visited_none << node
      end

      expect(visited_none).to be_empty
    end
  end

  describe "inheritance from PassBase" do
    it "inherits all PassBase functionality" do
      expect(pass_instance).to be_a(Kumi::Core::Analyzer::Passes::PassBase)
      expect(pass_instance).to respond_to(:run)

      # Should have access to PassBase protected methods
      expect(pass_instance.send(:schema)).to eq(schema)
      expect(pass_instance.send(:state)).to eq(state)
    end

    it "can use PassBase methods alongside visitor methods" do
      # Create a pass that uses both base and visitor functionality
      mixed_pass_class = Class.new(described_class) do
        def self.contract
          Kumi::Core::Analyzer::PassContract.new(provides: %i[visitor_test literal_count])
        end

        def run(errors)
          # Use visitor methods
          literal_count = 0
          visit_nodes_of_type(Kumi::Core::Syntax::Literal, errors: errors) do |_node, _decl, _errs|
            literal_count += 1
          end

          # Use new error reporting interface
          report_error(errors, "test error from visitor pass")

          # Return updated state
          state.with(:visitor_test, true)
               .with(:literal_count, literal_count)
        end
      end

      mixed_pass = mixed_pass_class.new(schema, state)
      result_state = mixed_pass.run(errors)

      expect(result_state[:visitor_test]).to be true
      expect(result_state[:literal_count]).to be > 0
      expect(errors.size).to eq(1)
      expect(errors.first.message).to eq("test error from visitor pass")
    end
  end
end
