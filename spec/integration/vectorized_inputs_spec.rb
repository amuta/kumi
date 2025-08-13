# frozen_string_literal: true

RSpec.describe "Vectorized Inputs Integration" do
  # Helper to perform the full analysis and compilation pipeline
  def analyze_and_compile(&schema_block)
    syntax_tree = Kumi.schema(&schema_block)
    analyzer_result = Kumi::Analyzer.analyze!(syntax_tree.syntax_tree)
    Kumi::Compiler.compile(syntax_tree.syntax_tree, analyzer: analyzer_result)
  end

  let(:order_schema) do
    analyze_and_compile do
      input do
        # The core feature: defining a schema for array elements
        array :line_items do
          float   :price
          integer :quantity
          string  :category
        end
        # A scalar input for broadcasting
        scalar :tax_rate, type: :float
      end

      # --- Vectorized (Map) Operations ---
      # These values are calculated for each line item.

      # Accessing element properties triggers vectorized calculation
      value :subtotals, input.line_items.price * input.line_items.quantity

      # Trait applied element-wise
      trait :is_taxable, (input.line_items.category != "digital")

      # Conditional logic applied element-wise
      value :taxes, fn(:if, is_taxable, subtotals * input.tax_rate, 0.0)

      # --- Aggregate (Reduce) Operations ---
      # These values operate on the results of the vectorized calculations.

      # `fn(:sum, ...)` consumes the `subtotals` vector to produce a scalar
      value :total_revenue, fn(:sum, subtotals)
      value :total_tax, fn(:sum, taxes)
    end
  end

  let(:input_data) do
    {
      line_items: [
        { price: 100.0, quantity: 2, category: "physical" }, # Taxable
        { price: 50.0,  quantity: 1, category: "digital"  }, # Non-taxable
        { price: 20.0,  quantity: 5, category: "physical" } # Taxable
      ],
      tax_rate: 0.1
    }
  end

  let(:runner) { order_schema.read(input_data, mode: :ruby) }

  it "correctly calculates vectorized values" do
    expect(runner[:subtotals]).to eq([200.0, 50.0, 100.0])
  end

  it "correctly applies vectorized traits and conditionals" do
    expect(runner[:taxes]).to eq([20.0, 0.0, 10.0])
  end

  it "correctly calculates aggregate values from vectorized results" do
    expect(runner[:total_revenue]).to eq(350.0) # 200 + 50 + 100
    expect(runner[:total_tax]).to eq(30.0) # 20 + 0 + 10
  end
end
