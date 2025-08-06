# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../compiler_refactor/tac_ir_generator'

RSpec.describe "TAC Decomposition" do
  def generate_tac_for_schema(schema_module)
    ast = schema_module.__syntax_tree__
    analysis_result = Kumi::Analyzer.analyze!(ast)
    
    generator = Kumi::Core::TACIRGenerator.new(ast, analysis_result)
    generator.generate
  end

  describe "Simple Expression Decomposition" do
    module SimpleSchema
      extend Kumi::Schema
      
      schema skip_compiler: true do
        input do
          array :items do
            float :value
          end
        end
        
        # Simple expression - no decomposition needed
        value :doubled, input.items.value * 2.0
      end
    end

    it "keeps simple expressions as single instructions" do
      tac_ir = generate_tac_for_schema(SimpleSchema)
      instructions = tac_ir[:instructions]
      
      expect(instructions.length).to eq(1)
      expect(instructions.first[:name]).to eq(:doubled)
      expect(instructions.first[:operation_type]).to eq(:vectorized)
      expect(instructions.first[:temp]).to be_falsey
    end
  end

  describe "Nested Expression Decomposition" do
    module NestedSchema
      extend Kumi::Schema
      
      schema skip_compiler: true do
        input do
          array :items do
            float :value
          end
          float :bonus
        end
        
        # Nested expression - should generate temp
        value :boosted, (input.items.value * 2.0) + input.bonus
      end
    end

    it "decomposes nested expressions into TAC form" do
      tac_ir = generate_tac_for_schema(NestedSchema)
      instructions = tac_ir[:instructions]
      
      # Should generate 2 instructions: temp + main
      expect(instructions.length).to eq(2)
      
      # First should be temp
      temp_instruction = instructions.first
      expect(temp_instruction[:name].to_s).to start_with('__temp_')
      expect(temp_instruction[:temp]).to be_truthy
      expect(temp_instruction[:operation_type]).to eq(:vectorized)
      
      # Second should be main operation
      main_instruction = instructions.last
      expect(main_instruction[:name]).to eq(:boosted)
      expect(main_instruction[:temp]).to be_falsey
      expect(main_instruction[:operation_type]).to eq(:vectorized)
      
      # Main should reference the temp
      temp_ref = main_instruction[:operands].find { |op| op[:type] == :declaration_reference }
      expect(temp_ref[:name]).to eq(temp_instruction[:name])
    end
  end

  describe "Declaration Reference (No Decomposition)" do
    module DeclarationRefSchema
      extend Kumi::Schema
      
      schema skip_compiler: true do
        input do
          array :items do
            float :value
          end
          float :multiplier
        end
        
        # First declare simple operation
        value :doubled, input.items.value * 2.0
        
        # Then reference it - no decomposition needed
        value :final, doubled + input.multiplier
      end
    end

    it "preserves declaration references without decomposition" do
      tac_ir = generate_tac_for_schema(DeclarationRefSchema)
      instructions = tac_ir[:instructions]
      
      expect(instructions.length).to eq(2)
      expect(instructions.map { |i| i[:name] }).to eq([:doubled, :final])
      expect(instructions.all? { |i| !i[:temp] }).to be_truthy
      
      # Final should reference doubled
      final_instruction = instructions.last
      ref_operand = final_instruction[:operands].find { |op| op[:type] == :declaration_reference }
      expect(ref_operand[:name]).to eq(:doubled)
    end
  end

  describe "Complex Nested Expression" do
    module ComplexSchema
      extend Kumi::Schema
      
      schema skip_compiler: true do
        input do
          array :items do
            float :price
            integer :qty
          end
          float :tax_rate
        end
        
        # Complex nested: (input.items.price * input.items.qty) * input.tax_rate
        value :total, (input.items.price * input.items.qty) * input.tax_rate
      end
    end

    it "decomposes complex expressions with multiple levels" do
      tac_ir = generate_tac_for_schema(ComplexSchema)
      instructions = tac_ir[:instructions]
      
      # Should generate at least 2 instructions
      expect(instructions.length).to be >= 2
      
      # Should have at least one temp
      temp_count = instructions.count { |i| i[:temp] }
      expect(temp_count).to be >= 1
      
      # Final instruction should be named :total and not be temp
      final_instruction = instructions.last
      expect(final_instruction[:name]).to eq(:total)
      expect(final_instruction[:temp]).to be_falsey
    end
  end

  describe "TAC Operand Format" do
    module OperandFormatSchema
      extend Kumi::Schema
      
      schema skip_compiler: true do
        input do
          array :data do
            float :value
          end
          float :threshold
        end
        
        value :result, input.data.value + input.threshold
      end
    end

    it "produces consistent TAC operand format" do
      tac_ir = generate_tac_for_schema(OperandFormatSchema)
      instruction = tac_ir[:instructions].first
      operands = instruction[:operands]
      
      # Should have input element reference
      elem_ref = operands.find { |op| op[:type] == :input_element_reference }
      expect(elem_ref).to include(
        type: :input_element_reference,
        path: [:data, :value],
        accessor: "data.value:element"
      )
      
      # Should have input reference
      input_ref = operands.find { |op| op[:type] == :input_reference }
      expect(input_ref).to include(
        type: :input_reference,
        name: :threshold,
        accessor: "threshold:structure"
      )
    end
  end
end