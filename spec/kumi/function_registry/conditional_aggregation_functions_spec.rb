# frozen_string_literal: true

RSpec.describe Kumi::Core::FunctionRegistry::CollectionFunctions do
  describe "conditional aggregation functions" do
    # Test metadata
    it_behaves_like "a function with correct metadata", :count_if, 1, [Kumi::Core::Types.array(:boolean)], :integer
    it_behaves_like "a function with correct metadata", :sum_if, 2, [Kumi::Core::Types.array(:float), Kumi::Core::Types.array(:boolean)],
                    :float
    it_behaves_like "a function with correct metadata", :avg_if, 2, [Kumi::Core::Types.array(:float), Kumi::Core::Types.array(:boolean)],
                    :float

    describe "count_if function" do
      it "counts true values in boolean arrays" do
        count_if_fn = Kumi::Registry.fetch(:count_if)

        expect(count_if_fn.call([true, false, true, false, true])).to eq(3)
        expect(count_if_fn.call([false, false, false])).to eq(0)
        expect(count_if_fn.call([true, true, true])).to eq(3)
        expect(count_if_fn.call([])).to eq(0)
      end
    end

    describe "sum_if function" do
      it "sums values where condition is true" do
        sum_if_fn = Kumi::Registry.fetch(:sum_if)

        values = [100.0, 200.0, 300.0, 400.0]
        conditions = [true, false, true, false]

        expect(sum_if_fn.call(values, conditions)).to eq(400.0)  # 100 + 300
      end

      it "returns 0 when no conditions are true" do
        sum_if_fn = Kumi::Registry.fetch(:sum_if)

        values = [10.0, 20.0, 30.0]
        conditions = [false, false, false]

        expect(sum_if_fn.call(values, conditions)).to eq(0.0)
      end

      it "handles empty arrays" do
        sum_if_fn = Kumi::Registry.fetch(:sum_if)

        expect(sum_if_fn.call([], [])).to eq(0)
      end
    end

    describe "avg_if function" do
      it "averages values where condition is true" do
        avg_if_fn = Kumi::Registry.fetch(:avg_if)

        values = [100.0, 200.0, 300.0, 400.0]
        conditions = [true, false, true, false]

        expect(avg_if_fn.call(values, conditions)).to eq(200.0)  # (100 + 300) / 2
      end

      it "returns 0.0 when no conditions are true" do
        avg_if_fn = Kumi::Registry.fetch(:avg_if)

        values = [10.0, 20.0, 30.0]
        conditions = [false, false, false]

        expect(avg_if_fn.call(values, conditions)).to eq(0.0)
      end

      it "handles single true condition" do
        avg_if_fn = Kumi::Registry.fetch(:avg_if)

        values = [42.0, 100.0, 200.0]
        conditions = [true, false, false]

        expect(avg_if_fn.call(values, conditions)).to eq(42.0)
      end
    end

    describe "real-world usage patterns" do
      it "works with sales data filtering" do
        # Simulate sales data processing
        prices = [1200.0, 15.0, 800.0, 150.0, 25.0]
        expensive = [true, false, true, true, false] # > 100
        electronics = [true, false, true, false, true] # electronics category

        count_if_fn = Kumi::Registry.fetch(:count_if)
        sum_if_fn = Kumi::Registry.fetch(:sum_if)
        avg_if_fn = Kumi::Registry.fetch(:avg_if)

        expect(count_if_fn.call(expensive)).to eq(3)
        expect(sum_if_fn.call(prices, expensive)).to eq(2150.0) # 1200 + 800 + 150
        expect(avg_if_fn.call(prices, expensive)).to be_within(0.01).of(716.67) # 2150/3

        expect(count_if_fn.call(electronics)).to eq(3)
        expect(sum_if_fn.call(prices, electronics)).to eq(2025.0) # 1200 + 800 + 25
        expect(avg_if_fn.call(prices, electronics)).to eq(675.0) # 2025/3
      end

      it "handles mixed positive and negative values" do
        amounts = [100.0, -50.0, 200.0, -25.0, 75.0]
        positive = [true, false, true, false, true]

        sum_if_fn = Kumi::Registry.fetch(:sum_if)
        avg_if_fn = Kumi::Registry.fetch(:avg_if)

        expect(sum_if_fn.call(amounts, positive)).to eq(375.0)  # 100 + 200 + 75
        expect(avg_if_fn.call(amounts, positive)).to eq(125.0)  # 375/3
      end

      it "demonstrates the power of combining multiple conditions" do
        values = [10.0, 20.0, 30.0, 40.0]
        condition1 = [true, false, true, false]
        condition2 = [false, true, true, false]

        # Simulate AND operation: both conditions true
        combined_and = condition1.zip(condition2).map { |a, b| a && b }
        # Simulate OR operation: either condition true
        combined_or = condition1.zip(condition2).map { |a, b| a || b }

        sum_if_fn = Kumi::Registry.fetch(:sum_if)

        expect(sum_if_fn.call(values, combined_and)).to eq(30.0)   # Only index 2: 30
        expect(sum_if_fn.call(values, combined_or)).to eq(60.0)    # Index 0,1,2: 10+20+30
      end
    end
  end
end
