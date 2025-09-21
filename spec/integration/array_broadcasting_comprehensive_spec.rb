# frozen_string_literal: true

RSpec.describe "Array Broadcasting Comprehensive Tests" do
  describe "Basic Element-wise Operations" do
    let(:runner) { run_schema_fixture("basic_element_wise_ops") }

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
    let(:runner) { run_schema_fixture("cascade_broadcasting") }

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
    let(:runner) { run_schema_fixture("aggregation_ops") }

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

  describe "Array Field Access Patterns" do
    let(:runner) { run_schema_fixture("array_field_access") }

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
      let(:runner) { run_schema_fixture("edge_case_empty_array") }

      it "handles empty arrays correctly" do
        expect(runner[:doubled]).to eq([])
        expect(runner[:sum_values]).to eq(0)
      end
    end

    describe "single element arrays" do
      let(:runner) { run_schema_fixture("edge_case_single_element_array") }

      it "handles single element arrays correctly" do
        expect(runner[:doubled]).to eq([10])
        expect(runner[:positive]).to be(true)
        expect(runner[:total]).to eq(10)
      end
    end

    describe "multiple cascade interactions" do
      let(:runner) { run_schema_fixture("edge_case_complex_cascade") }

      it "handles multiple cascade interactions" do
        expect(runner[:sale_prices]).to eq([120.0, 64.0, 200.0])
        expect(runner[:category_labels]).to eq(["Electronic Device", "General Item", "General Item"])
        expect(runner[:display_labels]).to eq(["Premium Item", "Sale Item", "Premium Item"])
      end
    end

    describe "mixed array and scalar references" do
      let(:runner) { run_schema_fixture("edge_case_mixed_scalar") }

      it "handles mixed array and scalar operations" do
        expect(runner[:scaled_values]).to eq([20.0, 40.0, 60.0])
        expect(runner[:bonus_values]).to eq([25.0, 45.0, 65.0])
        expect(runner[:total_with_bonus]).to eq(135.0)
        expect(runner[:final_total]).to eq(270.0)
      end
    end

    describe "nil values in arrays" do
      let(:runner) { run_schema_fixture("edge_case_nil_values") }

      it "handles nil values in vectorized operations" do
        expect(runner[:has_price]).to eq([true, false, true])
        expect(runner[:has_category]).to eq([true, true, false])
        expect(runner[:price_not_nil]).to eq([true, false, true])
        expect(runner[:prices_with_fallback]).to eq([100.0, 0.0, 50.0])
        expect(runner[:categories_with_fallback]).to eq(%w[books electronics unknown])
      end

      xit "handles complex nil operations with aggregations" do
        runner = run_schema_fixture("edge_case_nil_aggregations")

        expect(runner[:total_valid_prices]).to eq(150.0)
        expect(runner[:array_size]).to eq(3)
        expect(runner[:count_items_with_price]).to eq(2)
      end
    end
  end
end
