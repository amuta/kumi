# frozen_string_literal: true

RSpec.describe "Array Broadcasting Comprehensive Tests" do
  # Helper to perform the full analysis and compilation pipeline
  def analyze_and_compile(&schema_block)
    syntax_tree = Kumi.schema(&schema_block)
    analyzer_result = Kumi::Analyzer.analyze!(syntax_tree.syntax_tree)
    Kumi::Compiler.compile(syntax_tree.syntax_tree, analyzer: analyzer_result)
  end

  # Helper to create a runner with compiled schema and input data
  def create_runner(schema, input_data)
    Kumi::Core::SchemaInstance.new(schema, nil, input_data)
  end

  describe "Basic Element-wise Operations" do
    let(:basic_schema) do
      analyze_and_compile do
        input do
          array :items do
            float   :price
            integer :quantity
            string  :category
          end
          float :tax_rate
          float :multiplier
        end

        # Basic arithmetic operations
        value :subtotals, input.items.price * input.items.quantity
        value :discounted_prices, input.items.price * 0.9
        value :scaled_prices, input.items.price * input.multiplier

        # Comparison operations
        trait :expensive, input.items.price > 100.0
        trait :high_quantity, input.items.quantity >= 5
        trait :is_electronics, input.items.category == "electronics"

        # Conditional operations using fn(:if)
        value :conditional_prices, fn(:if, expensive, input.items.price * 0.8, input.items.price)
      end
    end

    let(:basic_input) do
      {
        items: [
          { price: 50.0, quantity: 2, category: "books" },
          { price: 150.0, quantity: 1, category: "electronics" },
          { price: 75.0, quantity: 6, category: "clothing" }
        ],
        tax_rate: 0.08,
        multiplier: 1.2
      }
    end

    let(:runner) { create_runner(basic_schema, basic_input) }

    it "performs basic arithmetic element-wise" do
      expect(runner[:subtotals]).to eq([100.0, 150.0, 450.0])
      expect(runner[:discounted_prices]).to eq([45.0, 135.0, 67.5])
      expect(runner[:scaled_prices]).to eq([60.0, 180.0, 90.0])
    end

    it "performs comparison operations element-wise" do
      expect(runner[:expensive]).to eq([false, true, false])
      expect(runner[:high_quantity]).to eq([false, false, true])
      expect(runner[:is_electronics]).to eq([false, true, false])
    end

    it "performs conditional operations element-wise" do
      expect(runner[:conditional_prices]).to eq([50.0, 120.0, 75.0])
    end
  end

  describe "Cascade Expression Broadcasting" do
    let(:cascade_schema) do
      analyze_and_compile do
        input do
          array :products do
            float   :price
            integer :stock
            string  :status
          end
          float :discount_rate
          integer :low_stock_threshold
        end

        # Base vectorized values
        trait :low_stock, input.products.stock < input.low_stock_threshold
        trait :available, input.products.status == "available"
        value :base_prices, input.products.price

        # Cascades with vectorized results (proper cascade syntax)
        value :effective_prices do
          on low_stock, fn(:multiply, base_prices, fn(:subtract, 1, input.discount_rate))
          base base_prices
        end

        value :availability_status do
          on available, "In Stock"
          on low_stock, "Low Stock"
          base "Out of Stock"
        end

        # Simple cascades
        value :final_prices do
          on available, effective_prices
          base 0.0
        end

        # Cascades referencing other vectorized values
        value :display_prices do
          on available, effective_prices
          base fn(:multiply, base_prices, 0.5)
        end
      end
    end

    let(:cascade_input) do
      {
        products: [
          { price: 100.0, stock: 15, status: "available" },
          { price: 200.0, stock: 3, status: "available" },
          { price: 50.0, stock: 0, status: "discontinued" }
        ],
        discount_rate: 0.1,
        low_stock_threshold: 5
      }
    end

    let(:runner) { create_runner(cascade_schema, cascade_input) }

    it "applies cascades to vectorized values correctly" do
      expect(runner[:effective_prices]).to eq([100.0, 180.0, 45.0])
      expect(runner[:availability_status]).to eq(["In Stock", "In Stock", "Low Stock"])
    end

    it "handles simple cascade conditions" do
      expect(runner[:final_prices]).to eq([100.0, 180.0, 0.0])
    end

    it "handles cascades referencing other vectorized values" do
      expect(runner[:display_prices]).to eq([100.0, 180.0, 25.0])
    end
  end

  describe "Aggregation and Reduction Operations" do
    let(:aggregation_schema) do
      analyze_and_compile do
        input do
          array :transactions do
            float   :amount
            string  :type
            integer :day
          end
        end

        # Vectorized calculations
        trait :is_debit, input.transactions.type == "debit"
        trait :is_credit, input.transactions.type == "credit"
        value :absolute_amounts, fn(:abs, input.transactions.amount)

        # Direct aggregations
        value :total_amount, fn(:sum, input.transactions.amount)
        value :max_amount, fn(:max, absolute_amounts)
        value :min_amount, fn(:min, absolute_amounts)
        value :transaction_count, fn(:size, input.transactions)

        # Conditional aggregations using cascades
        value :debit_amounts do
          on is_debit, input.transactions.amount
          base 0.0
        end

        value :credit_amounts do
          on is_credit, input.transactions.amount
          base 0.0
        end

        value :total_debits, fn(:sum, debit_amounts)
        value :total_credits, fn(:sum, credit_amounts)

        # Complex aggregations
        value :net_balance, total_credits + total_debits
      end
    end

    let(:aggregation_input) do
      {
        transactions: [
          { amount: 100.0, type: "credit", day: 1 },
          { amount: -50.0, type: "debit", day: 2 },
          { amount: 200.0, type: "credit", day: 3 },
          { amount: -25.0, type: "debit", day: 3 }
        ]
      }
    end

    let(:runner) { create_runner(aggregation_schema, aggregation_input) }

    it "performs basic aggregation operations" do
      expect(runner[:total_amount]).to eq(225.0)
      expect(runner[:max_amount]).to eq(200.0)
      expect(runner[:min_amount]).to eq(25.0)
      expect(runner[:transaction_count]).to eq(4)
    end

    it "performs conditional aggregations" do
      expect(runner[:total_debits]).to eq(-75.0)
      expect(runner[:total_credits]).to eq(300.0)
      expect(runner[:net_balance]).to eq(225.0)
    end
  end

  describe "Type Inference for Vectorized Operations" do
    let(:type_schema) do
      analyze_and_compile do
        input do
          array :numbers do
            integer :int_val
            float   :float_val
          end
          array :strings do
            string :text
          end
        end

        # Integer operations should remain integer arrays
        value :doubled_ints, input.numbers.int_val * 2

        # Float operations should be float arrays
        value :scaled_floats, input.numbers.float_val * 1.5

        # Mixed int/float should be float arrays
        value :mixed_math, input.numbers.int_val * input.numbers.float_val

        # String operations should be string arrays
        value :uppercased, fn(:upcase, input.strings.text)

        # Boolean operations should be boolean arrays
        trait :large_numbers, input.numbers.int_val > 10

        # Aggregations should be scalars
        value :sum_ints, fn(:sum, doubled_ints)       # scalar integer
        value :avg_floats, fn(:avg, scaled_floats)    # scalar float
      end
    end

    let(:analyzer_result) do
      syntax_tree = Kumi.schema do
        input do
          array :numbers do
            integer :int_val
            float   :float_val
          end
          array :strings do
            string :text
          end
        end

        value :doubled_ints, input.numbers.int_val * 2
        value :scaled_floats, input.numbers.float_val * 1.5
        value :mixed_math, input.numbers.int_val * input.numbers.float_val
        value :uppercased, fn(:upcase, input.strings.text)
        trait :large_numbers, input.numbers.int_val > 10
        value :sum_ints, fn(:sum, doubled_ints)
      end

      Kumi::Analyzer.analyze!(syntax_tree.syntax_tree)
    end

    it "infers correct types for vectorized operations" do
      types = analyzer_result.state[:inferred_types]

      expect(types[:doubled_ints]).to eq({ array: :integer })
      expect(types[:scaled_floats]).to eq({ array: :float })
      expect(types[:mixed_math]).to eq({ array: :float })
      expect(types[:uppercased]).to eq({ array: :any })
      expect(types[:large_numbers]).to eq({ array: :boolean })
    end

    it "infers correct types for aggregation operations" do
      types = analyzer_result.state[:inferred_types]

      expect(types[:sum_ints]).to eq(:float)
    end
  end

  describe "Array Field Access Patterns" do
    let(:array_access_schema) do
      analyze_and_compile do
        input do
          array :orders do
            string :customer_name
            float  :order_total
            string :status
          end
          float :vip_discount
        end

        # Simple array field access
        value :customer_names, input.orders.customer_name
        value :order_totals, input.orders.order_total

        # Conditions on array fields
        trait :high_value, input.orders.order_total > 100.0
        trait :completed, input.orders.status == "completed"

        # Operations on array fields
        value :discounted_totals do
          on high_value, fn(:multiply, order_totals, fn(:subtract, 1, input.vip_discount))
          base order_totals
        end
      end
    end

    let(:array_access_input) do
      {
        orders: [
          { customer_name: "Alice", order_total: 150.0, status: "completed" },
          { customer_name: "Bob", order_total: 50.0, status: "pending" },
          { customer_name: "Carol", order_total: 200.0, status: "completed" }
        ],
        vip_discount: 0.15
      }
    end

    let(:runner) { create_runner(array_access_schema, array_access_input) }

    it "handles array field access" do
      expect(runner[:customer_names]).to eq(%w[Alice Bob Carol])
      expect(runner[:order_totals]).to eq([150.0, 50.0, 200.0])
    end

    it "applies conditions to array fields" do
      expect(runner[:high_value]).to eq([true, false, true])
      expect(runner[:completed]).to eq([true, false, true])
    end

    it "handles cascades with array field conditions" do
      expect(runner[:discounted_totals]).to eq([127.5, 50.0, 170.0])
    end
  end

  describe "Edge Cases and Boundary Conditions" do
    describe "empty arrays" do
      let(:empty_schema) do
        analyze_and_compile do
          input do
            array :items do
              float :value
            end
          end

          value :doubled, input.items.value * 2
          value :sum_values, fn(:sum, doubled)
        end
      end

      let(:empty_input) { { items: [] } }
      let(:runner) { create_runner(empty_schema, empty_input) }

      it "handles empty arrays correctly" do
        expect(runner[:doubled]).to eq([])
        expect(runner[:sum_values]).to eq(0)
      end
    end

    describe "single element arrays" do
      let(:single_schema) do
        analyze_and_compile do
          input do
            array :items do
              integer :count
            end
          end

          value :doubled, input.items.count * 2
          value :sum_count, fn(:sum, input.items.count)
          trait :positive, sum_count > 0
          value :total, fn(:sum, doubled)
        end
      end

      let(:single_input) { { items: [{ count: 5 }] } }
      let(:runner) { create_runner(single_schema, single_input) }

      it "handles single element arrays correctly" do
        expect(runner[:doubled]).to eq([10])
        expect(runner[:positive]).to be(true)
        expect(runner[:total]).to eq(10)
      end
    end

    describe "multiple cascade interactions" do
      let(:complex_cascade_schema) do
        analyze_and_compile do
          input do
            array :items do
              float :price
              string :category
              boolean :on_sale
            end
            float :sale_discount
          end

          trait :is_expensive, input.items.price > 100.0
          trait :is_on_sale, input.items.on_sale == true
          trait :is_electronics, input.items.category == "electronics"

          # Simple cascades (proper cascade syntax)
          value :sale_prices do
            on is_on_sale, fn(:multiply, input.items.price, fn(:subtract, 1, input.sale_discount))
            base input.items.price
          end

          value :category_labels do
            on is_electronics, "Electronic Device"
            base "General Item"
          end

          # Multiple cascade conditions
          value :display_labels do
            on is_expensive, "Premium Item"
            on is_on_sale, "Sale Item"
            base "Regular Item"
          end
        end
      end

      let(:complex_input) do
        {
          items: [
            { price: 150.0, category: "electronics", on_sale: true },
            { price: 80.0, category: "books", on_sale: true },
            { price: 200.0, category: "furniture", on_sale: false }
          ],
          sale_discount: 0.2
        }
      end

      let(:runner) { create_runner(complex_cascade_schema, complex_input) }

      it "handles multiple cascade interactions" do
        expect(runner[:sale_prices]).to eq([120.0, 64.0, 200.0])
        expect(runner[:category_labels]).to eq(["Electronic Device", "General Item", "General Item"])
        expect(runner[:display_labels]).to eq(["Premium Item", "Sale Item", "Premium Item"])
      end
    end

    describe "mixed array and scalar references" do
      let(:mixed_schema) do
        analyze_and_compile do
          input do
            array :items do
              float :value
            end
            float :multiplier
            float :bonus
          end

          # Mix of vectorized and scalar values
          value :scaled_values, input.items.value * input.multiplier
          value :bonus_values, scaled_values + input.bonus

          # Aggregation with scalar arithmetic
          value :total_with_bonus, fn(:sum, bonus_values)
          value :final_total, total_with_bonus * input.multiplier
        end
      end

      let(:mixed_input) do
        {
          items: [
            { value: 10.0 },
            { value: 20.0 },
            { value: 30.0 }
          ],
          multiplier: 2.0,
          bonus: 5.0
        }
      end

      let(:runner) { create_runner(mixed_schema, mixed_input) }

      it "handles mixed array and scalar operations" do
        expect(runner[:scaled_values]).to eq([20.0, 40.0, 60.0])
        expect(runner[:bonus_values]).to eq([25.0, 45.0, 65.0])
        expect(runner[:total_with_bonus]).to eq(135.0)
        expect(runner[:final_total]).to eq(270.0)
      end
    end

    describe "nil values in arrays" do
      let(:nil_schema) do
        analyze_and_compile do
          input do
            array :items do
              float :price
              string :category
            end
          end

          # TODO: -> Better way?

          # Vectorized operations with potential nils (sugar syntax)
          trait :has_price, fn(:!=, input.items.price, nil)
          trait :has_category, fn(:!=, input.items.category, nil)
          # Alternative functional syntax also works:
          trait :price_not_nil, fn(:!=, input.items.price, nil)
          value :prices_with_fallback do
            on has_price, input.items.price
            base 0.0
          end
          value :categories_with_fallback do
            on has_category, input.items.category
            base "unknown"
          end
        end
      end

      let(:nil_input) do
        {
          items: [
            { price: 100.0, category: "books" },
            { price: nil, category: "electronics" },
            { price: 50.0, category: nil }
          ]
        }
      end

      let(:runner) { create_runner(nil_schema, nil_input) }

      it "handles nil values in vectorized operations" do
        expect(runner[:has_price]).to eq([true, false, true])
        expect(runner[:has_category]).to eq([true, true, false])
        expect(runner[:price_not_nil]).to eq([true, false, true]) # Functional syntax
        expect(runner[:prices_with_fallback]).to eq([100.0, 0.0, 50.0])
        expect(runner[:categories_with_fallback]).to eq(%w[books electronics unknown])
      end

      xit "handles complex nil operations with aggregations" do
        # Add aggregation tests
        schema_with_aggregations = analyze_and_compile do
          input do
            array :items do
              float :price
            end
          end

          trait :has_price, fn(:!=, input.items.price, nil)
          value :valid_prices do
            on has_price, input.items.price
            base 0.0
          end
          value :total_valid_prices, fn(:sum, valid_prices)
          value :array_size, fn(:size, has_price)

          # Count actual true values using conditional mapping
          value :count_indicators, fn(:if, has_price, 1, 0)
          value :count_items_with_price, fn(:sum, count_indicators)
        end

        runner = create_runner(schema_with_aggregations, nil_input)

        # Total should only include non-nil prices: 100.0 + 50.0 = 150.0
        expect(runner[:total_valid_prices]).to eq(150.0)

        # Array size should be 3 (array has 3 elements)
        expect(runner[:array_size]).to eq(3)

        # Count of items with price should be 2 (true, false, true = 2 items with price)
        expect(runner[:count_items_with_price]).to eq(2)
      end
    end

    describe "dimension mismatch errors" do
      it "detects and reports dimension mismatches between different array inputs" do
        expect do
          analyze_and_compile do
            input do
              array :items do
                string :name
              end
              array :logs do
                string :user_name
              end
            end

            # This should error - comparing arrays from different inputs
            trait :same_name, input.items.name == input.logs.user_name
          end
        end.to raise_error(
          Kumi::Core::Errors::SemanticError,
          /Cannot broadcast operation across arrays from different sources: items, logs.*Problem: Multiple operands are arrays from different sources:.*- Operand.*resolves to array\(string\) from array 'items'.*- Operand.*resolves to array\(string\) from array 'logs'/m
        )
      end

      it "provides descriptive error messages for mixed array operations" do
        expect do
          analyze_and_compile do
            input do
              array :products do
                float :price
              end
              array :orders do
                integer :quantity
              end
            end

            # This should error with descriptive message
            value :totals, input.products.price * input.orders.quantity
          end
        end.to raise_error(
          Kumi::Core::Errors::SemanticError,
          /Cannot broadcast operation across arrays from different sources: products, orders.*Problem: Multiple operands are arrays from different sources:.*- Operand.*resolves to array\(float\) from array 'products'.*- Operand.*resolves to array\(integer\) from array 'orders'/m
        )
      end
    end
  end
end
