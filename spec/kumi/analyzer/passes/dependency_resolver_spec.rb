# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::DependencyResolver do
  include ASTFactory

  let(:state) { Kumi::Core::Analyzer::AnalysisState.new(declarations: definitions, input_metadata: input_meta) }
  let(:input_meta) { {} }
  let(:errors) { [] }
  let(:definitions) do
    {
      price: attr(:price, lit(100)),
      discount: attr(:discount, lit(10)),
      high_value: trait(:high_value, call(:>, ref(:price), lit(50)))
    }
  end

  def run(schema)
    @result_state = described_class.new(schema, state).run(errors)
  end

  def dependency_graph
    @result_state[:dependencies]
  end

  def leaf_map
    @result_state[:leaves]
  end

  describe ".run" do
    context "with simple reference dependencies" do
      let(:schema) do
        final_price = attr(:final_price, call(:subtract, ref(:price), ref(:discount)))
        syntax(:root, [], [final_price], [], loc: loc)
      end

      it "builds dependency graph with reference edges" do
        run(schema)

        graph = dependency_graph
        expect(graph[:final_price].size).to eq(2)

        price_edge = graph[:final_price].find { |e| e.to == :price }
        discount_edge = graph[:final_price].find { |e| e.to == :discount }

        expect(price_edge.type).to eq(:ref)
        expect(price_edge.via).to eq(:subtract)
        expect(discount_edge.type).to eq(:ref)
        expect(discount_edge.via).to eq(:subtract)
      end
    end

    context "with field (key) dependencies" do
      let(:schema) do
        total = attr(:total, call(:add, field_ref(:base_amount), field_ref(:tax)))
        syntax(:root, [], [total], [], loc: loc)
      end

      it "builds dependency graph with key edges and populates leaf map" do
        run(schema)

        graph = dependency_graph
        expect(graph[:total].size).to eq(2)

        base_edge = graph[:total].find { |e| e.to == :base_amount }
        tax_edge = graph[:total].find { |e| e.to == :tax }

        expect(base_edge.type).to eq(:key)
        expect(tax_edge.type).to eq(:key)

        # Check leaf map includes field nodes
        leaves = leaf_map
        expect(leaves[:total]).to include(an_object_having_attributes(name: :base_amount))
        expect(leaves[:total]).to include(an_object_having_attributes(name: :tax))
      end
    end

    context "with literal dependencies" do
      let(:schema) do
        constant = attr(:constant, lit(42))
        syntax(:root, [], [constant], [], loc: loc)
      end

      it "populates leaf map with literal nodes" do
        run(schema)

        leaves = leaf_map
        expect(leaves[:constant]).to include(an_object_having_attributes(value: 42))

        # No dependency edges for pure literals
        graph = dependency_graph
        expect(graph[:constant] || []).to be_empty
      end
    end

    context "with nested function calls" do
      let(:schema) do
        complex = attr(:complex, call(:multiply,
                                      call(:add, ref(:price), lit(5)),
                                      call(:subtract, field_ref(:quantity), lit(1))))
        syntax(:root, [], [complex], [], loc: loc)
      end

      it "tracks context through nested calls" do
        run(schema)

        graph = dependency_graph
        price_edge = graph[:complex].find { |e| e.to == :price }
        quantity_edge = graph[:complex].find { |e| e.to == :quantity }

        # The immediate parent function context is preserved
        expect(price_edge.via).to eq(:add)
        expect(quantity_edge.via).to eq(:subtract)
      end
    end

    context "with undefined references" do
      let(:schema) do
        broken = attr(:broken, call(:add, ref(:nonexistent), ref(:price)))
        syntax(:root, [], [broken], [], loc: loc)
      end

      it "reports undefined reference errors" do
        run(schema)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/undefined reference to `nonexistent`/)

        # Still builds edges for valid references
        graph = dependency_graph
        valid_edge = graph[:broken].find { |e| e.to == :price }
        expect(valid_edge).not_to be_nil
      end
    end

    context "with mixed dependency types" do
      let(:input_meta) { { premium_rate: {}, standard_rate: {} } }

      let(:schema) do
        mixed = attr(:mixed, call(:if,
                                  call(:>, ref(:price), lit(100)),
                                  field_ref(:premium_rate),
                                  field_ref(:standard_rate)))
        syntax(:root, [field_decl(:premium_rate), field_decl(:standard_rate)], [mixed], [], loc: loc)
      end

      it "handles references and keys in the same expression" do
        run(schema)

        graph = dependency_graph
        edges = graph[:mixed]

        ref_edge = edges.find { |e| e.type == :ref }
        edges.select { |e| e.type == :input }

        expect(ref_edge.to).to eq(:price)
        key_edges = edges.select { |e| e.type == :key }
        expect(key_edges.map(&:to)).to contain_exactly(:premium_rate, :standard_rate)
      end
    end

    context "with trait dependencies" do
      let(:schema) do
        expensive = trait(:expensive, call(:>, ref(:price), lit(1000)))
        syntax(:root, [], [], [expensive], loc: loc)
      end

      it "builds dependencies for trait expressions" do
        run(schema)

        graph = dependency_graph
        price_edge = graph[:expensive].find { |e| e.to == :price }

        expect(price_edge.type).to eq(:ref)
        expect(price_edge.via).to eq(:>)
      end
    end

    context "with cascade expressions" do
      let(:schema) do
        # Create cascade expression manually
        case1 = when_case_expression(call(:>, ref(:price), lit(1000)), lit(0.2))
        case2 = when_case_expression(call(:>, ref(:price), lit(500)), lit(0.1))
        default_case = when_case_expression(lit(true), lit(0.05))
        cascade_expr = syntax(:cascade_expr, [case1, case2, default_case], loc: loc)

        cascade = attr(:discount_rate, cascade_expr)
        syntax(:root, [], [cascade], [], loc: loc)
      end

      it "extracts dependencies from all cascade conditions" do
        run(schema)

        graph = dependency_graph
        price_edges = graph[:discount_rate].select { |e| e.to == :price }

        # Should have edges for each condition that references :price
        expect(price_edges.length).to be >= 2
        price_edges.each do |edge|
          expect(edge.type).to eq(:ref)
        end
      end
    end

    context "when state is frozen after execution" do
      let(:schema) { syntax(:root, [], [attr(:simple, lit(1))], [], loc: loc) }

      it "freezes the dependency graph and leaf map" do
        run(schema)

        expect(dependency_graph).to be_frozen
        expect(leaf_map).to be_frozen
        expect(dependency_graph.values.all?(&:frozen?)).to be true
        expect(leaf_map.values.all?(&:frozen?)).to be true
      end
    end

    context "when referencing a nested input field" do
      let(:schema) do
        inputs = [
          input_decl(:user, :array, nil, access_mode: :field, children: [
                       input_decl(:name, :string),
                       input_decl(:age, :integer)
                     ])
        ]
        total = attr(:total, call(:add, input_elem_ref(%i[user name]), input_elem_ref(%i[user age])))
        syntax(:root, inputs, [total], [], loc: loc)
      end

      it "correctly resolves nested input references" do
        run(schema)

        graph = dependency_graph
        expect(graph[:total].size).to eq(2)

        name_edge = graph[:total].find { |e| e.to == :user }
        age_edge = graph[:total].find { |e| e.to == :user }

        expect(name_edge.type).to eq(:key)
        expect(age_edge.type).to eq(:key)
      end
    end
  end
end
