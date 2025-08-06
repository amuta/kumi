# frozen_string_literal: true

require 'spec_helper'
require_relative '../../compiler_refactor/tac_ir_generator'
require_relative '../../compiler_refactor/tac_ir_compiler'

RSpec.describe "TAC Expression Decomposition Integration" do
  def compile_with_tac(schema_module)
    ast = schema_module.__syntax_tree__
    analysis_result = Kumi::Analyzer.analyze!(ast)
    
    # Generate TAC IR
    tac_generator = Kumi::Core::TACIRGenerator.new(ast, analysis_result)
    tac_ir = tac_generator.generate
    
    # Compile TAC IR
    tac_compiler = Kumi::Core::TACIRCompiler.new(tac_ir)
    compiled_schema = tac_compiler.compile
    
    { tac_ir: tac_ir, compiled_schema: compiled_schema }
  end

  describe "Simple to Complex Expression Decomposition" do
    context "simple expression (no decomposition needed)" do
      module SimpleExpression
        extend Kumi::Schema
        
        schema do
          input do
            array :numbers, elem: { type: :float }
          end
          
          # Simple: input.numbers * 2.0
          value :doubled, input.numbers * 2.0
        end
      end

      it "generates single TAC instruction" do
        result = compile_with_tac(SimpleExpression)
        instructions = result[:tac_ir][:instructions]
        
        expect(instructions.length).to eq(1)
        expect(instructions.first[:name]).to eq(:doubled)
        expect(instructions.first[:temp]).to be_falsey
      end

      it "executes correctly" do
        result = compile_with_tac(SimpleExpression)
        runner = result[:compiled_schema]
        
        test_data = { numbers: [1.0, 2.0, 3.0] }
        actual = runner.bindings[:doubled].call(test_data)
        
        expect(actual).to eq([2.0, 4.0, 6.0])
      end
    end

    context "nested expression (decomposition required)" do 
      module NestedExpression
        extend Kumi::Schema
        
        schema do
          input do
            array :items do
              float :value
            end
            float :bonus
          end
          
          # Nested: (input.items.value * 2.0) + input.bonus
          value :boosted, (input.items.value * 2.0) + input.bonus
        end
      end

      it "decomposes into TAC instructions with temp" do
        result = compile_with_tac(NestedExpression)
        instructions = result[:tac_ir][:instructions]
        
        expect(instructions.length).to eq(2)
        
        # First instruction should be temp for (input.items.value * 2.0)
        temp_instruction = instructions.first
        expect(temp_instruction[:name].to_s).to start_with('__temp_')
        expect(temp_instruction[:temp]).to be_truthy
        expect(temp_instruction[:operation_type]).to eq(:vectorized)
        
        # Second instruction should be the main operation referencing temp
        main_instruction = instructions.last
        expect(main_instruction[:name]).to eq(:boosted)
        expect(main_instruction[:temp]).to be_falsey
        
        # Main should reference the temp
        temp_ref = main_instruction[:operands].find { |op| op[:type] == :declaration_reference }
        expect(temp_ref[:name]).to eq(temp_instruction[:name])
      end

      it "executes decomposed instructions correctly" do
        result = compile_with_tac(NestedExpression)
        runner = result[:compiled_schema]
        
        test_data = { 
          items: [{ value: 10.0 }, { value: 20.0 }], 
          bonus: 5.0 
        }
        
        actual = runner.bindings[:boosted].call(test_data)
        # Should be [(10*2)+5, (20*2)+5] = [25.0, 45.0]
        expect(actual).to eq([25.0, 45.0])
      end
    end

    context "declaration reference (no decomposition)" do
      module DeclarationReference
        extend Kumi::Schema
        
        schema do
          input do
            array :items do
              float :value
            end
            float :multiplier
          end
          
          # First declare the operation
          value :doubled, input.items.value * 2.0
          
          # Then reference it (no decomposition needed)
          value :final, doubled + input.multiplier
        end
      end

      it "preserves declaration references without decomposition" do
        result = compile_with_tac(DeclarationReference)
        instructions = result[:tac_ir][:instructions]
        
        expect(instructions.length).to eq(2)
        
        # Both should be non-temp instructions
        expect(instructions.all? { |inst| !inst[:temp] }).to be_truthy
        expect(instructions.map { |inst| inst[:name] }).to eq([:doubled, :final])
        
        # Second instruction should reference first
        final_instruction = instructions.last
        ref_operand = final_instruction[:operands].find { |op| op[:type] == :declaration_reference }
        expect(ref_operand[:name]).to eq(:doubled)
      end

      it "executes declaration chain correctly" do
        result = compile_with_tac(DeclarationReference)
        runner = result[:compiled_schema]
        
        test_data = { 
          items: [{ value: 5.0 }, { value: 10.0 }], 
          multiplier: 3.0 
        }
        
        doubled_result = runner.bindings[:doubled].call(test_data)
        final_result = runner.bindings[:final].call(test_data)
        
        expect(doubled_result).to eq([10.0, 20.0])  # [5*2, 10*2]
        expect(final_result).to eq([13.0, 23.0])    # [10+3, 20+3]
      end
    end

    context "deeply nested expression" do
      module DeepNesting
        extend Kumi::Schema
        
        schema do
          input do
            array :items do
              float :price
              integer :qty
            end
            float :tax_rate
            float :shipping
          end
          
          # Deep: ((input.items.price * input.items.qty) + input.shipping) * input.tax_rate
          value :total_cost, ((input.items.price * input.items.qty) + input.shipping) * input.tax_rate
        end
      end

      it "decomposes deeply nested expressions into multiple temps" do
        result = compile_with_tac(DeepNesting)
        instructions = result[:tac_ir][:instructions]
        
        # Should generate multiple instructions
        expect(instructions.length).to be >= 2
        
        # Should have at least one temp instruction
        temp_instructions = instructions.select { |inst| inst[:temp] }
        expect(temp_instructions.length).to be >= 1
        
        # Final instruction should not be temp
        final_instruction = instructions.last
        expect(final_instruction[:name]).to eq(:total_cost)
        expect(final_instruction[:temp]).to be_falsey
      end
    end
  end

  describe "TAC Instruction Format" do
    module InstructionFormat
      extend Kumi::Schema
      
      schema do
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
      result = compile_with_tac(InstructionFormat)
      instruction = result[:tac_ir][:instructions].first
      operands = instruction[:operands]
      
      # Should have input_element_reference
      elem_ref = operands.find { |op| op[:type] == :input_element_reference }
      expect(elem_ref).to include(
        type: :input_element_reference,
        path: [:data, :value],
        accessor: "data.value:element"
      )
      
      # Should have input_reference
      input_ref = operands.find { |op| op[:type] == :input_reference }
      expect(input_ref).to include(
        type: :input_reference,
        name: :threshold,
        accessor: "threshold:structure"
      )
    end
  end
end