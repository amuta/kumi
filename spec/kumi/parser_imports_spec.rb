# frozen_string_literal: true

RSpec.describe "Schema import parsing" do
  def parse_schema(&block)
    Kumi::Core::RubyParser::Dsl.build_syntax_tree(&block)
  end

  # Create mock modules for testing
  module Schemas
    module Tax; end
    module Costs; end
    module Pricing; end
    module Funcs; end
    module Process; end
  end

  describe "import declaration parsing" do
    it "parses single import" do
      ast = parse_schema do
        import :tax, from: Schemas::Tax
        input { decimal :amount }
        value :result, ref(:result)
      end

      expect(ast.imports.size).to eq(1)
      expect(ast.imports[0].names).to eq([:tax])
      expect(ast.imports[0].module_ref).to eq(Schemas::Tax)
    end

    it "parses multiple imports from same module" do
      ast = parse_schema do
        import :tax, :shipping, from: Schemas::Costs
        input { decimal :amount }
        value :result, ref(:result)
      end

      expect(ast.imports[0].names).to eq([:tax, :shipping])
    end


    it "errors on import without from:" do
      expect do
        parse_schema do
          import :tax
          input { decimal :amount }
          value :result, ref(:result)
        end
      end.to raise_error(ArgumentError)
    end

    it "errors on invalid from: reference" do
      expect do
        parse_schema do
          import :tax, from: "not_a_module"
          input { decimal :amount }
          value :result, ref(:result)
        end
      end.to raise_error(Kumi::Core::Errors::SyntaxError)
    end

    it "accepts Class as from: reference" do
      class TestSchema; end

      ast = parse_schema do
        import :tax, from: TestSchema
        input { decimal :amount }
        value :result, ref(:result)
      end

      expect(ast.imports[0].module_ref).to eq(TestSchema)
    end
  end

  describe "import call parsing" do
    it "parses import call with single kwarg" do
      ast = parse_schema do
        import :tax, from: Schemas::Tax
        input { decimal :price }
        value :result, fn(:tax, amount: input.price)
      end

      result_value = ast.values[0]
      expect(result_value.expression).to be_a(Kumi::Syntax::ImportCall)
      expect(result_value.expression.fn_name).to eq(:tax)
    end

    it "parses import call with multiple kwargs" do
      ast = parse_schema do
        import :discount, from: Schemas::Pricing
        input do
          decimal :price
          integer :category
        end
        value :result, fn(:discount, price: input.price, category_id: input.category)
      end

      result_value = ast.values[0]
      expect(result_value.expression).to be_a(Kumi::Syntax::ImportCall)
      expect(result_value.expression.input_mapping.keys).to contain_exactly(:price, :category_id)
    end

    it "stores mapping expressions correctly" do
      ast = parse_schema do
        import :tax, from: Schemas::Tax
        input do
          decimal :amount
          decimal :multiplier
        end
        value :result, fn(:tax, amount: input.amount * input.multiplier)
      end

      result_value = ast.values[0]
      mapping = result_value.expression.input_mapping
      expect(mapping[:amount]).to be_a(Kumi::Syntax::CallExpression)
    end

    it "allows multiple calls to same imported function with different mappings" do
      ast = parse_schema do
        import :tax, from: Schemas::Tax
        input do
          decimal :subtotal
          array :items do
            hash :item do
              decimal :price
            end
          end
        end

        value :order_tax, fn(:tax, amount: input.subtotal)
        value :item_tax, fn(:tax, amount: input.items.item.price)
      end

      order_value = ast.values[0]
      item_value = ast.values[1]

      expect(order_value.expression).to be_a(Kumi::Syntax::ImportCall)
      expect(item_value.expression).to be_a(Kumi::Syntax::ImportCall)
      expect(order_value.expression.fn_name).to eq(:tax)
      expect(item_value.expression.fn_name).to eq(:tax)
    end
  end

  describe "distinguishing import calls from normal calls" do
    it "creates CallExpression for non-imported functions with positional args" do
      ast = parse_schema do
        input { decimal :x }
        value :abs_x, fn(:abs, input.x)
      end

      abs_value = ast.values[0]
      expect(abs_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(abs_value.expression).not_to be_a(Kumi::Syntax::ImportCall)
    end

    it "creates CallExpression for non-imported functions with kwargs" do
      ast = parse_schema do
        input { decimal :x }
        value :clamped, fn(:clamp, value: input.x, min: 0, max: 100)
      end

      clamped_value = ast.values[0]
      expect(clamped_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(clamped_value.expression).not_to be_a(Kumi::Syntax::ImportCall)
    end

    it "creates ImportCall only for imported functions with kwargs" do
      ast = parse_schema do
        import :my_func, from: Schemas::Funcs
        input { decimal :x }
        value :result, fn(:my_func, param: input.x)
      end

      result_value = ast.values[0]
      expect(result_value.expression).to be_a(Kumi::Syntax::ImportCall)
    end

    it "creates CallExpression when imported function called with positional args" do
      ast = parse_schema do
        import :my_func, from: Schemas::Funcs
        input { decimal :x }
        value :result, fn(:my_func, input.x)
      end

      result_value = ast.values[0]
      expect(result_value.expression).to be_a(Kumi::Syntax::CallExpression)
      expect(result_value.expression).not_to be_a(Kumi::Syntax::ImportCall)
    end
  end

  describe "root structure" do
    it "includes imports in root children" do
      ast = parse_schema do
        import :tax, from: Schemas::Tax
        input { decimal :amount }
        value :result, ref(:result)
      end

      expect(ast.children).to include(ast.imports)
    end

    it "empty imports array when no imports" do
      ast = parse_schema do
        input { decimal :amount }
        value :result, input.amount + 1
      end

      expect(ast.imports).to be_empty
    end
  end

  describe "error handling" do
    it "errors on positional import args" do
      expect do
        parse_schema do
          import(:tax, Schemas::Tax)
          input { decimal :amount }
          value :result, ref(:result)
        end
      end.to raise_error
    end
  end

  describe "import with expressions" do
    it "stores complex expressions in import call mapping" do
      ast = parse_schema do
        import :discount, from: Schemas::Pricing
        input do
          decimal :base_price
          decimal :quantity
        end
        value :result, fn(:discount, price: input.base_price * input.quantity)
      end

      mapping = ast.values[0].expression.input_mapping
      expect(mapping[:price]).to be_a(Kumi::Syntax::CallExpression)
    end

    it "stores nested array access in mapping" do
      ast = parse_schema do
        import :process, from: Schemas::Process
        input do
          array :items do
            hash :item do
              decimal :value
            end
          end
        end
        value :result, fn(:process, val: input.items.item.value)
      end

      mapping = ast.values[0].expression.input_mapping
      expect(mapping[:val]).to be_a(Kumi::Syntax::InputElementReference)
    end
  end
end
