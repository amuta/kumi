# frozen_string_literal: true

require_relative "cascade_ir_generator"
require_relative "tac_decomposer"
require_relative "ir_generator/input_accessors"
require_relative "ir_generator/instruction_builder"
require_relative "ir_generator/expression_ir"
require_relative "ir_generator/operand_mapper"
require_relative "ir_generator/type_resolver"

module Kumi
  module Core
    # Generates structured IR from analyzer result
    # Modular design with focused responsibilities
    class IRGenerator
      include TACDecomposer
      include IRGeneratorModules::InputAccessors
      include IRGeneratorModules::InstructionBuilder
      include IRGeneratorModules::ExpressionIR
      include IRGeneratorModules::OperandMapper
      include IRGeneratorModules::TypeResolver

      def initialize(syntax_tree, analysis_result)
        @syntax_tree = syntax_tree
        @analysis = analysis_result
        @cascade_ir_generator = CascadeIrGenerator.new(self)
        @state = analysis_result.state
        initialize_tac
      end

      # Methods for CascadeIrGenerator to use TAC decomposition  
      def generate_temp_name
        super  # Delegate to TACDecomposer module
      end

      def add_pending_temp_instruction(instruction)
        @pending_temp_instructions ||= []
        @pending_temp_instructions << instruction
      end

      # Override flush to include cascade temps
      def flush_temp_instructions
        cascade_temps = @pending_temp_instructions || []
        @pending_temp_instructions = []
        
        # Get regular TAC temps
        tac_temps = super
        
        # Combine both types of temps
        cascade_temps + tac_temps
      end

      def generate
        {
          # Pre-computed accessors for all input paths
          accessors: generate_accessors,
          
          # Compilation instructions in evaluation order
          instructions: generate_instructions,
          
          # Dependencies preserved for debugging  
          dependencies: @state[:dependencies] || {}
        }
      end
    end
  end
end