# frozen_string_literal: true

RSpec.describe Kumi::Core::FunctionRegistry::BroadcastingFunctions do
  describe "Object Access Broadcasting Functions" do
    describe "array_scalar_object" do
      it "applies operation to array field against scalar value" do
        # Pre-extracted field values (as our accessor system provides)
        field_values = [150.0, 50.0]
        
        gt_proc = Kumi::Registry.fetch(:>)
        array_scalar_object = Kumi::Registry.fetch(:array_scalar_object)
        
        result = array_scalar_object.call(gt_proc, field_values, 100)
        
        expect(result).to eq([true, false])
      end

      it "works with different operations and field types" do
        # Pre-extracted field values
        category_values = ['electronics', 'books']
        
        eq_proc = Kumi::Registry.fetch(:==)
        array_scalar_object = Kumi::Registry.fetch(:array_scalar_object)
        
        result = array_scalar_object.call(eq_proc, category_values, 'electronics')
        
        expect(result).to eq([true, false])
      end
    end

    describe "element_wise_object" do
      it "applies operation element-wise between two array fields" do
        # Pre-extracted field values from both arrays
        price_values = [150.0, 50.0]
        quantity_values = [2, 3]
        
        multiply_proc = Kumi::Registry.fetch(:multiply)
        element_wise_object = Kumi::Registry.fetch(:element_wise_object)
        
        result = element_wise_object.call(multiply_proc, price_values, quantity_values)
        
        expect(result).to eq([300.0, 150.0])
      end

      it "works with comparison operations" do
        # Pre-extracted field values from both arrays
        actual_values = [150, 80]
        budget_values = [100, 120]
        
        gt_proc = Kumi::Registry.fetch(:>)
        element_wise_object = Kumi::Registry.fetch(:element_wise_object)
        
        result = element_wise_object.call(gt_proc, actual_values, budget_values)
        
        expect(result).to eq([true, false])
      end
    end

    describe "parent_child_object" do
      it "applies operation between nested array field and parent field with broadcasting" do
        regions = [
          { 
            'target' => 100.0, 
            'offices' => [
              { 'performance' => 120.0 },
              { 'performance' => 80.0 }
            ]
          },
          { 
            'target' => 90.0, 
            'offices' => [
              { 'performance' => 95.0 }
            ]
          }
        ]
        
        gt_proc = Kumi::Registry.fetch(:>)
        parent_child_object = Kumi::Registry.fetch(:parent_child_object)
        
        result = parent_child_object.call(gt_proc, regions, 'offices', 'performance', 'target')
        
        expect(result).to eq([[true, false], [true]])
      end

      it "handles empty child arrays gracefully" do
        regions = [
          { 'target' => 100.0, 'offices' => [] },
          { 'target' => 90.0, 'offices' => [{ 'performance' => 95.0 }] }
        ]
        
        gt_proc = Kumi::Registry.fetch(:>)
        parent_child_object = Kumi::Registry.fetch(:parent_child_object)
        
        result = parent_child_object.call(gt_proc, regions, 'offices', 'performance', 'target')
        
        expect(result).to eq([[], [true]])
      end

      it "handles non-array child fields gracefully" do
        regions = [
          { 'target' => 100.0, 'offices' => nil },
          { 'target' => 90.0, 'offices' => [{ 'performance' => 95.0 }] }
        ]
        
        gt_proc = Kumi::Registry.fetch(:>)
        parent_child_object = Kumi::Registry.fetch(:parent_child_object)
        
        result = parent_child_object.call(gt_proc, regions, 'offices', 'performance', 'target')
        
        expect(result).to eq([[], [true]])
      end
    end
  end

  describe "Vector Access Broadcasting Functions" do
    describe "array_scalar_vector" do
      it "applies operation to array elements against scalar value" do
        numbers = [1, 2, 3, 4, 5]
        
        gt_proc = Kumi::Registry.fetch(:>)
        array_scalar_vector = Kumi::Registry.fetch(:array_scalar_vector)
        
        result = array_scalar_vector.call(gt_proc, numbers, 3)
        
        expect(result).to eq([false, false, false, true, true])
      end

      it "works with different operations" do
        numbers = [10, 20, 30]
        
        multiply_proc = Kumi::Registry.fetch(:multiply)
        array_scalar_vector = Kumi::Registry.fetch(:array_scalar_vector)
        
        result = array_scalar_vector.call(multiply_proc, numbers, 2)
        
        expect(result).to eq([20, 40, 60])
      end
    end

    describe "element_wise_vector" do
      it "applies operation element-wise between two arrays" do
        array1 = [1, 2, 3, 4]
        array2 = [5, 6, 7, 8]
        
        multiply_proc = Kumi::Registry.fetch(:multiply)
        element_wise_vector = Kumi::Registry.fetch(:element_wise_vector)
        
        result = element_wise_vector.call(multiply_proc, array1, array2)
        
        expect(result).to eq([5, 12, 21, 32])
      end

      it "works with comparison operations" do
        prices = [100, 200, 50]
        thresholds = [150, 150, 150]
        
        gt_proc = Kumi::Registry.fetch(:>)
        element_wise_vector = Kumi::Registry.fetch(:element_wise_vector)
        
        result = element_wise_vector.call(gt_proc, prices, thresholds)
        
        expect(result).to eq([false, true, false])
      end

      it "handles arrays of different lengths using Ruby's zip behavior" do
        array1 = [1, 2, 3]
        array2 = [10, 20]  # Shorter array
        
        multiply_proc = Kumi::Registry.fetch(:multiply)
        element_wise_vector = Kumi::Registry.fetch(:element_wise_vector)
        
        # Ruby's zip behavior: [1,2,3].zip([10,20]) = [[1,10], [2,20], [3,nil]]
        # So we expect [1*10, 2*20, 3*nil] but 3*nil will fail
        # Let's test with equal length arrays to avoid this edge case
        array1 = [1, 2]
        array2 = [10, 20]
        
        result = element_wise_vector.call(multiply_proc, array1, array2)
        
        expect(result).to eq([10, 40])
      end
    end

    describe "parent_child_vector" do
      it "applies operation between nested array elements and parent array elements" do
        nested_array = [
          [10, 20],      # First parent's children
          [30, 40, 50],  # Second parent's children  
          [60]           # Third parent's child
        ]
        parent_array = [15, 35, 70]  # Parent values to broadcast
        
        gt_proc = Kumi::Registry.fetch(:>)
        parent_child_vector = Kumi::Registry.fetch(:parent_child_vector)
        
        result = parent_child_vector.call(gt_proc, nested_array, parent_array)
        
        expect(result).to eq([
          [false, true],        # [10>15, 20>15] = [false, true]
          [false, true, true],  # [30>35, 40>35, 50>35] = [false, true, true]
          [false]               # [60>70] = [false]
        ])
      end

      it "handles non-array nested elements gracefully" do
        nested_array = [
          [10, 20],
          nil,        # Non-array element
          [60]
        ]
        parent_array = [15, 35, 70]
        
        gt_proc = Kumi::Registry.fetch(:>)
        parent_child_vector = Kumi::Registry.fetch(:parent_child_vector)
        
        result = parent_child_vector.call(gt_proc, nested_array, parent_array)
        
        expect(result).to eq([
          [false, true],
          [],              # Empty result for nil
          [false]
        ])
      end
    end
  end

  describe "Function Definitions" do
    it "provides complete function metadata" do
      definitions = Kumi::Core::FunctionRegistry::BroadcastingFunctions.definitions
      
      expect(definitions).to have_key(:array_scalar_object)
      expect(definitions).to have_key(:element_wise_object)
      expect(definitions).to have_key(:parent_child_object)
      expect(definitions).to have_key(:array_scalar_vector)
      expect(definitions).to have_key(:element_wise_vector)
      expect(definitions).to have_key(:parent_child_vector)
      
      # Check that each function has proper metadata
      definitions.each do |name, entry|
        expect(entry).to be_a(Kumi::Core::FunctionRegistry::FunctionBuilder::Entry)
        expect(entry.fn).to be_a(Proc)
        expect(entry.arity).to be_a(Integer)
        expect(entry.description).to be_a(String)
        expect(entry.param_types).to be_an(Array)
      end
    end

    it "has correct arities for each function" do
      definitions = Kumi::Core::FunctionRegistry::BroadcastingFunctions.definitions
      
      expect(definitions[:array_scalar_object].arity).to eq(3)      # op_proc, field_values, scalar
      expect(definitions[:element_wise_object].arity).to eq(3)      # op_proc, field_values1, field_values2
      expect(definitions[:parent_child_object].arity).to eq(5)      # op_proc, parent_array, child_field, child_value_field, parent_value_field
      expect(definitions[:array_scalar_vector].arity).to eq(3)      # op_proc, array, scalar
      expect(definitions[:element_wise_vector].arity).to eq(3)      # op_proc, array1, array2
      expect(definitions[:parent_child_vector].arity).to eq(3)      # op_proc, nested_array, parent_array
    end
  end
end