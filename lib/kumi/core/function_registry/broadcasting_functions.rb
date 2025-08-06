# frozen_string_literal: true

module Kumi
  module Core
    module FunctionRegistry
      # Clean broadcasting functions based on our strategy taxonomy
      module BroadcastingFunctions
        def self.definitions
          {
            # ===== OBJECT ACCESS STRATEGIES =====

            # Array field vs scalar value: items.price > 100
            array_scalar_object: FunctionBuilder::Entry.new(
              fn: lambda do |op_proc, field_values, scalar_value|
                field_values.map do |value|
                  op_proc.call(value, scalar_value)
                end
              end,
              arity: 3,
              param_types: [:any, Kumi::Core::Types.array(:any), :any],
              return_type: Kumi::Core::Types.array(:any),
              description: "Apply operation to array field values against scalar value"
            ),

            # Array field vs array field (same level): items.price * items.quantity
            element_wise_object: FunctionBuilder::Entry.new(
              fn: lambda do |op_proc, field_values1, field_values2|
                field_values1.zip(field_values2).map do |value1, value2|
                  op_proc.call(value1, value2)
                end
              end,
              arity: 3,
              param_types: [:any, Kumi::Core::Types.array(:any), Kumi::Core::Types.array(:any)],
              return_type: Kumi::Core::Types.array(:any),
              description: "Apply operation between two array field values element-wise"
            ),

            # Nested field vs parent field: offices.performance > regions.target
            parent_child_object: FunctionBuilder::Entry.new(
              fn: lambda do |op_proc, parent_array, child_field, child_value_field, parent_value_field|
                parent_array.map do |parent_item|
                  parent_value = parent_item[parent_value_field.to_s] || parent_item[parent_value_field.to_sym]
                  child_array = parent_item[child_field.to_s] || parent_item[child_field.to_sym]
                  
                  if child_array.is_a?(Array)
                    child_array.map do |child_item|
                      child_value = child_item[child_value_field.to_s] || child_item[child_value_field.to_sym]
                      op_proc.call(child_value, parent_value)
                    end
                  else
                    []
                  end
                end
              end,
              arity: 5,
              param_types: [:any, Kumi::Core::Types.array(:any), :string, :string, :string],
              return_type: Kumi::Core::Types.array(Kumi::Core::Types.array(:any)),
              description: "Apply operation between nested array field and parent field with broadcasting"
            ),

            # ===== VECTOR ACCESS STRATEGIES =====

            # Array elements vs scalar: matrix[i] > threshold
            array_scalar_vector: FunctionBuilder::Entry.new(
              fn: lambda do |op_proc, array, scalar_value|
                array.map do |element|
                  op_proc.call(element, scalar_value)
                end
              end,
              arity: 3,
              param_types: [:any, Kumi::Core::Types.array(:any), :any],
              return_type: Kumi::Core::Types.array(:any),
              description: "Apply operation to array elements against scalar value"
            ),

            # Array elements vs array elements: matrix1[i] * matrix2[i]
            element_wise_vector: FunctionBuilder::Entry.new(
              fn: lambda do |op_proc, array1, array2|
                array1.zip(array2).map do |element1, element2|
                  op_proc.call(element1, element2)
                end
              end,
              arity: 3,
              param_types: [:any, Kumi::Core::Types.array(:any), Kumi::Core::Types.array(:any)],
              return_type: Kumi::Core::Types.array(:any),
              description: "Apply operation element-wise between two arrays"
            ),

            # Nested array elements vs parent array elements: cube[i][j] > matrix[i]
            parent_child_vector: FunctionBuilder::Entry.new(
              fn: lambda do |op_proc, nested_array, parent_array|
                nested_array.each_with_index.map do |nested_sub_array, parent_index|
                  parent_value = parent_array[parent_index]
                  
                  if nested_sub_array.is_a?(Array)
                    nested_sub_array.map do |nested_element|
                      op_proc.call(nested_element, parent_value)
                    end
                  else
                    []
                  end
                end
              end,
              arity: 3,
              param_types: [:any, Kumi::Core::Types.array(Kumi::Core::Types.array(:any)), Kumi::Core::Types.array(:any)],
              return_type: Kumi::Core::Types.array(Kumi::Core::Types.array(:any)),
              description: "Apply operation between nested array elements and parent array elements"
            ),

          }
        end
      end
    end
  end
end